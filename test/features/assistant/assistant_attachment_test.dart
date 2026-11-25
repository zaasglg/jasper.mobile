import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/assistant/data/services/assistant_attachment_picker.dart';
import 'package:jospar/features/assistant/data/repositories/assistant_repository_impl.dart';
import 'package:jospar/features/assistant/data/models/assistant_message_dto.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_message_model.dart';
import 'package:jospar/features/assistant/domain/entities/assistant_attachment.dart';
import 'package:jospar/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:jospar/features/assistant/presentation/widgets/assistant_web_layout.dart';

void main() {
  final file = AssistantAttachmentPicker.fromBytes(
    'plan.csv',
    Uint8List.fromList(utf8.encode('task,owner\nAPI,Aliya\n')),
  );
  test('upload uses the exact name MIME byte count and canonical data URL', () {
    expect(file.mimeType, 'text/csv');
    expect(file.size, 21);
    expect(
      AssistantAttachmentPicker.fromBytes(
        'module.py',
        Uint8List.fromList(utf8.encode('#!/usr/bin/python3\nprint(1)')),
      ).name,
      'module.py',
    );
    expect(file.dataUrl, 'data:text/csv;base64,dGFzayxvd25lcgpBUEksQWxpeWEK');
    final message = AssistantMessageModel(
      role: 'user',
      content: '',
      attachments: [file],
    );
    expect(
      AssistantMessageDto.fromJson(
        AssistantMessageDto.fromEntity(message).toJson(),
      ).toEntity(),
      message,
    );
    expect(
      AssistantAttachmentPicker.fromBytes(
        'module.py',
        Uint8List.fromList(utf8.encode('print(1)')),
      ).name,
      'module.py',
    );
  });
  for (final name in [
    'SETUP.EXE',
    'photo.apk.pdf',
    'script.PS1',
    'book.xlsm',
    'test.exe. ',
    '../plan.csv',
  ]) {
    test('blocks dangerous or invalid name $name', () {
      expect(
        () =>
            AssistantAttachmentPicker.fromBytes(name, Uint8List.fromList([1])),
        throwsA(isA<AssistantException>()),
      );
    });
  }
  for (final bytes in [
    <int>[0x4d, 0x5a, 0, 0],
    <int>[0x7f, 0x45, 0x4c, 0x46],
    <int>[0xfe, 0xed, 0xfa, 0xcf],
    utf8.encode('#!/bin/sh\necho test'),
  ]) {
    test('blocks renamed executable signature $bytes', () {
      expect(
        () => AssistantAttachmentPicker.fromBytes(
          'plan.pdf',
          Uint8List.fromList(bytes),
        ),
        throwsA(isA<AssistantException>()),
      );
    });
  }
  test('blocks zero bytes and size above 8 MiB', () {
    expect(
      () => AssistantAttachmentPicker.fromBytes('file.txt', Uint8List(0)),
      throwsA(isA<AssistantException>()),
    );
    expect(
      () => AssistantAttachmentPicker.fromBytes('file.txt', Uint8List(8388609)),
      throwsA(isA<AssistantException>()),
    );
  });
  test(
    'chat sends only current attachments, preserving reports in DTO',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'content': 'Ответ',
                    if ((options.data as Map).containsKey('attachments'))
                      'attachments': [
                        {
                          'name': 'plan.csv',
                          'mimeType': 'text/csv',
                          'size': 21,
                          'status': 'analyzed',
                          'analysisMode': 'text',
                          'truncated': true,
                        },
                      ],
                  },
                ),
              );
            },
          ),
        );
      final repo = AssistantRepositoryImpl(dio);
      final history = [
        AssistantMessageModel(
          role: 'user',
          content: 'План',
          attachments: [file],
        ),
      ];
      final reply = await repo.chat(
        workspaceId: 'w',
        messages: history,
        attachments: [file],
      );
      expect(requests.first.headers['X-Workspace-Id'], 'w');
      expect(requests.first.data['attachments'], [file.toUploadJson()]);
      expect(requests.first.data['messages'], [
        {'role': 'user', 'content': 'План'},
      ]);
      expect(reply.attachments.single.truncated, isTrue);
      expect(
        AssistantMessageDto.fromJson(
          AssistantMessageDto.fromEntity(reply).toJson(),
        ).toEntity(),
        reply,
      );
      await repo.chat(
        workspaceId: 'w',
        messages: [
          ...history,
          reply,
          const AssistantMessageModel(role: 'user', content: 'Продолжай'),
        ],
      );
      expect(requests.last.data.containsKey('attachments'), isFalse);
      await expectLater(
        repo.chat(
          workspaceId: 'w',
          messages: history,
          attachments: [file, file, file, file],
        ),
        throwsA(isA<AssistantException>()),
      );
      expect(requests.length, 2);
    },
  );
  test(
    'server must confirm file reading, and typed/DTO errors are shown',
    () async {
      for (final errorBody in [
        {'code': 'ATTACHMENT_BUSY', 'message': 'Файл обрабатывается'},
        {
          'message': ['size is too large', 'name is invalid'],
        },
      ]) {
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 400,
                      data: errorBody,
                    ),
                  ),
                );
              },
            ),
          );
        await expectLater(
          AssistantRepositoryImpl(
            dio,
          ).chat(workspaceId: 'w', messages: [], attachments: [file]),
          throwsA(
            isA<AssistantException>().having(
              (e) => e.message,
              'message',
              contains(
                errorBody['code'] == null
                    ? 'size is too large'
                    : 'Файл обрабатывается',
              ),
            ),
          ),
        );
      }
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) => h.resolve(
              Response(
                requestOptions: o,
                data: {'content': 'Ответ без чтения'},
              ),
            ),
          ),
        );
      await expectLater(
        AssistantRepositoryImpl(
          dio,
        ).chat(workspaceId: 'w', messages: [], attachments: [file]),
        throwsA(isA<AssistantException>()),
      );
    },
  );
  testWidgets(
    'unsupported and partial file reports remain readable on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    AssistantFileTile(
                      file: AssistantAttachment(
                        name: 'audio.mp3',
                        mimeType: 'audio/mpeg',
                        size: 100,
                        status: 'unsupported',
                        reason: 'Приложите расшифровку',
                      ),
                    ),
                    AssistantFileTile(
                      file: AssistantAttachment(
                        name: 'plan.pdf',
                        mimeType: 'application/pdf',
                        size: 100,
                        status: 'analyzed',
                        analysisMode: 'text',
                        truncated: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Не прочитан'), findsOneWidget);
      expect(find.text('Прочитан частично'), findsOneWidget);
      expect(find.text('Приложите расшифровку'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
