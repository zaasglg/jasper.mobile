import '../../../core/widgets/app_snack_bar.dart';
import 'package:pdfx/pdfx.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/service_locator.dart';
import '../domain/entities/storage_scope.dart';
import '../domain/entities/storage_item.dart';
import '../domain/entities/storage_enums.dart';
import '../domain/storage_repository.dart';
import 'storage_cubit.dart';

String storageSafeName(String name) {
  final safe = name
      .replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_')
      .replaceAll('..', '_');
  return safe.isEmpty ? 'file' : safe;
}

Future<void> openStorageLink(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw const StorageException('Не удалось открыть ссылку');
  }
}

Future<void> saveStorageFile(
  StorageRepository repository,
  StorageScope scope,
  StorageItem item,
) async {
  final bytes = await repository.bytes(scope, item);
  await FilePicker.saveFile(
    fileName: storageSafeName(item.name),
    bytes: bytes,
    mimeType: item.mimeType.isEmpty
        ? 'application/octet-stream'
        : item.mimeType,
  );
}

class StorageFileScreen extends StatefulWidget {
  const StorageFileScreen({required this.scope, required this.item, super.key});
  final StorageScope scope;
  final StorageItem item;
  @override
  State<StorageFileScreen> createState() => _StorageFileScreenState();
}

class _StorageFileScreenState extends State<StorageFileScreen> {
  final _token = CancelToken();
  late Future<Uint8List> _bytes;
  bool _busy = false;
  StorageRepository get repository => sl<StorageRepository>();
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bytes = repository.bytes(widget.scope, widget.item, cancelToken: _token);
  }

  @override
  void dispose() {
    _token.cancel();
    super.dispose();
  }

  Future<void> _open(Uint8List bytes, {bool save = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (save) {
        await FilePicker.saveFile(
          fileName: storageSafeName(widget.item.name),
          bytes: bytes,
          mimeType: widget.item.mimeType.isEmpty
              ? 'application/octet-stream'
              : widget.item.mimeType,
        );
      } else {
        final dir = await Directory(
          '${(await getTemporaryDirectory()).path}/jospar-storage/${DateTime.now().microsecondsSinceEpoch}',
        ).create(recursive: true);
        final file = await File(
          '${dir.path}/${storageSafeName(widget.item.name)}',
        ).writeAsBytes(bytes);
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          throw const StorageException(
            'Нет приложения для открытия файла. Сохраните его на устройство.',
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(StorageCubit.errorText(error)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(StorageCubit.errorText(snapshot.error!)),
                  TextButton(
                    onPressed: () => setState(_load),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final bytes = snapshot.data!;
        return SafeArea(
          child: Column(
            children: [
              Expanded(
                child: widget.item.kind == StorageFileKind.image
                    ? InteractiveViewer(
                        minScale: .5,
                        maxScale: 5,
                        child: Center(
                          child: Image.memory(
                            bytes,
                            errorBuilder: (_, _, _) =>
                                const Text('Не удалось отобразить изображение'),
                          ),
                        ),
                      )
                    : widget.item.kind == StorageFileKind.pdf
                    ? _PdfPreview(
                        bytes: bytes,
                        onOpenExternally: () => _open(bytes),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.fileText, size: 40),
                              const SizedBox(height: 16),
                              Text(
                                widget.item.name,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(widget.item.sizeLabel),
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: _busy ? null : () => _open(bytes),
                                child: const Text('Открыть файл'),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _open(bytes, save: true),
                    icon: const Icon(LucideIcons.download, size: 16),
                    label: Text(
                      _busy ? 'Подождите…' : 'Сохранить на устройство',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({required this.bytes, required this.onOpenExternally});
  final Uint8List bytes;
  final VoidCallback onOpenExternally;
  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  late final PdfControllerPinch _controller;
  int _page = 1, _pages = 0;
  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openData(widget.bytes),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: PdfViewPinch(
          controller: _controller,
          maxScale: 5,
          backgroundDecoration: const BoxDecoration(color: Color(0xFFF5F5F3)),
          onDocumentLoaded: (document) {
            if (mounted) setState(() => _pages = document.pagesCount);
          },
          onPageChanged: (page) {
            if (mounted) setState(() => _page = page);
          },
          builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            documentLoaderBuilder: (_) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            pageLoaderBuilder: (_) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorBuilder: (_, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Не удалось отобразить PDF',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: widget.onOpenExternally,
                      child: const Text('Открыть другим приложением'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (_pages > 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '$_page / $_pages',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
    ],
  );
}
