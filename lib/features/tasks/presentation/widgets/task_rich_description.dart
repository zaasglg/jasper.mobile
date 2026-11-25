import 'package:jospar/core/localization/app_translations.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/utils/html_text.dart';

/// Shared allow-list for website-authored HTML. Never execute stored markup.
String sanitizeTaskDescription(String source) {
  final fragment = html.parseFragment(source);
  const allowed = {
    'p',
    'div',
    'span',
    'br',
    'strong',
    'b',
    'em',
    'i',
    'u',
    's',
    'strike',
    'del',
    'ul',
    'ol',
    'li',
    'blockquote',
    'h1',
    'h2',
    'h3',
    'pre',
    'code',
    'a',
    'hr',
    'table',
    'thead',
    'tbody',
    'tr',
    'td',
    'th',
  };
  String visit(dom.Node node) {
    if (node is dom.Text) {
      return const HtmlEscape(HtmlEscapeMode.element).convert(node.data);
    }
    if (node is! dom.Element) return '';
    final tag = node.localName!;
    if (const {
      'script',
      'style',
      'iframe',
      'object',
      'embed',
      'form',
      'input',
      'svg',
      'math',
      'template',
    }.contains(tag)) {
      return '';
    }
    final content = node.nodes.map(visit).join();
    if (!allowed.contains(tag)) return content;
    var attributes = '';
    if (tag == 'a') {
      final uri = Uri.tryParse(node.attributes['href'] ?? '');
      if (uri != null && {'https', 'http', 'mailto'}.contains(uri.scheme)) {
        attributes =
            ' href="${const HtmlEscape(HtmlEscapeMode.attribute).convert(uri.toString())}"';
      }
    }
    final align = RegExp(
      r'text-align:\s*(left|right|center|justify)\s*(?:;|$)',
    ).firstMatch(node.attributes['style'] ?? '')?.group(1);
    if (align != null) attributes += ' style="text-align:$align"';
    return tag == 'br' || tag == 'hr'
        ? '<$tag>'
        : '<$tag$attributes>$content</$tag>';
  }

  return fragment.nodes.map(visit).join();
}

class TaskRichDescriptionView extends StatelessWidget {
  const TaskRichDescriptionView({
    required this.value,
    this.maxLines,
    super.key,
  });
  final String value;
  final int? maxLines;
  @override
  Widget build(BuildContext context) {
    final fragment = html.parseFragment(sanitizeTaskDescription(value));
    InlineSpan visit(dom.Node node, TextStyle inherited) {
      if (node is dom.Text) return TextSpan(text: node.data, style: inherited);
      if (node is! dom.Element) return const TextSpan();
      final tag = node.localName;
      var style = inherited;
      if ({'b', 'strong', 'h1', 'h2', 'h3', 'th'}.contains(tag)) {
        style = style.copyWith(fontWeight: FontWeight.w700);
      }
      if ({'i', 'em', 'blockquote'}.contains(tag)) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      }
      if (tag == 'u' || tag == 'a') {
        style = style.copyWith(decoration: TextDecoration.underline);
      }
      if ({'s', 'strike', 'del'}.contains(tag)) {
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      }
      if (tag == 'pre' || tag == 'code') {
        style = style.copyWith(fontFamily: 'monospace');
      }
      if (tag == 'h1') style = style.copyWith(fontSize: 20);
      if (tag == 'h2') style = style.copyWith(fontSize: 18);
      if (tag == 'h3') style = style.copyWith(fontSize: 16);
      if (tag == 'br' || tag == 'hr') return const TextSpan(text: '\n');
      return TextSpan(
        children: [
          if (tag == 'li') const TextSpan(text: '• '),
          ...node.nodes.map((n) => visit(n, style)),
          if ({
            'p',
            'div',
            'li',
            'blockquote',
            'pre',
            'h1',
            'h2',
            'h3',
            'tr',
          }.contains(tag))
            const TextSpan(text: '\n'),
          if (tag == 'td' || tag == 'th') const TextSpan(text: '  '),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        children: fragment.nodes
            .map((n) => visit(n, const TextStyle()))
            .toList(),
      ),
      style: const TextStyle(fontSize: 13, height: 1.45),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}

class TaskRichDescriptionEditor extends StatefulWidget {
  const TaskRichDescriptionEditor({
    required this.initial,
    this.onSave,
    super.key,
  });
  final String initial;
  final Future<bool> Function(String)? onSave;
  @override
  State<TaskRichDescriptionEditor> createState() =>
      _TaskRichDescriptionEditorState();
}

class _TaskRichDescriptionEditorState extends State<TaskRichDescriptionEditor> {
  WebViewController? _web;
  late final _plain = TextEditingController(
    text: htmlToPlainText(widget.initial),
  );
  bool _ready = false, _fallback = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (kIsWeb ||
        ![
          TargetPlatform.iOS,
          TargetPlatform.android,
        ].contains(defaultTargetPlatform)) {
      setState(() => _fallback = true);
      return;
    }
    try {
      final web = WebViewController();
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.addJavaScriptChannel(
        'Description',
        onMessageReceived: (message) async {
          if (!mounted) return;
          try {
            final data = jsonDecode(message.message);
            if (data['type'] == 'ready') {
              setState(() => _ready = true);
            } else if (data['type'] == 'save' && data['html'] is String) {
              await _commit(sanitizeTaskDescription(data['html'] as String));
            }
          } catch (_) {
            /* Ignore malformed editor messages. */
          }
        },
      );
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
      await web.loadHtmlString(buildTaskDescriptionEditorHtml(widget.initial));
      if (mounted) setState(() => _web = web);
    } catch (_) {
      if (mounted) setState(() => _fallback = true);
    }
  }

  void _save() {
    if (_fallback) {
      final unchanged = _plain.text == htmlToPlainText(widget.initial);
      _commit(
        unchanged
            ? widget.initial
            : '<p>${const HtmlEscape().convert(_plain.text).replaceAll('\n', '<br>')}</p>',
      );
    } else {
      _web?.runJavaScript('window.saveDescription()');
    }
  }

  Future<void> _commit(String html) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    var success = false;
    try {
      success = await widget.onSave?.call(html) ?? true;
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, html);
    } else {
      setState(() {
        _saving = false;
        _error =
            'Не удалось сохранить описание. Текст сохранён в редакторе — попробуйте ещё раз.';
      });
    }
  }

  @override
  void dispose() {
    _plain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    MediaQuery.paddingOf(context).vertical -
                    24)
                .clamp(180.0, MediaQuery.sizeOf(context).height * .75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Описание'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Отмена'),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AbsorbPointer(
                absorbing: _saving,
                child: _fallback
                    ? TextField(
                        controller: _plain,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: tr(context, 'Добавьте описание…'),
                        ),
                      )
                    : _web == null
                    ? const Center(child: CircularProgressIndicator())
                    : WebViewWidget(controller: _web!),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr(context, _error!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: !_saving && (_ready || _fallback) ? _save : null,
              child: Text(tr(context, 'Сохранить')),
            ),
          ],
        ),
      ),
    ),
  );
}

String buildTaskDescriptionEditorHtml(String initial) {
  // Keep user markup out of script and the host document until sanitized.
  final encoded = base64Encode(utf8.encode(sanitizeTaskDescription(initial)));
  return '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>
body{margin:0;color:#23232a;font:15px -apple-system,system-ui,sans-serif;background:white}#tools{display:flex;flex-wrap:wrap;gap:4px;padding:8px 0;border-bottom:1px solid #eee;position:sticky;top:0;background:white;z-index:1}button,select{border:0;border-radius:7px;padding:8px;background:#f5f5f7;color:#53515d;font-size:14px}button:active{background:#eee9ff}#editor{outline:none;min-height:200px;padding:12px 4px;line-height:1.5;overflow-wrap:anywhere}p{margin:0 0 10px}blockquote{border-left:3px solid #ccc;padding-left:12px;margin:10px}pre{background:#f5f5f5;padding:10px}table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:5px}a{color:#705ce7}
</style></head><body><div id="tools">
<button data-command="undo" aria-label="Отменить">↶</button><button data-command="redo" aria-label="Повторить">↷</button>
<select aria-label="Стиль текста" onchange="format('formatBlock',this.value)"><option value="p">Текст</option><option value="h1">Заголовок 1</option><option value="h2">Заголовок 2</option><option value="h3">Заголовок 3</option><option value="blockquote">Цитата</option><option value="pre">Блок кода</option></select>
<button data-command="bold" aria-label="Жирный"><b>B</b></button><button data-command="italic" aria-label="Курсив"><i>I</i></button><button data-command="underline" aria-label="Подчеркнутый"><u>U</u></button><button data-command="strikeThrough" aria-label="Зачеркнутый"><s>S</s></button>
<button data-command="insertUnorderedList" aria-label="Маркированный список">• Список</button><button data-command="insertOrderedList" aria-label="Нумерованный список">1. Список</button><button data-command="justifyLeft" aria-label="По левому краю">≡←</button><button data-command="justifyCenter" aria-label="По центру">≡</button><button data-command="justifyRight" aria-label="По правому краю">→≡</button><button data-command="insertHorizontalRule" aria-label="Разделитель">―</button><input id="linkValue" type="url" placeholder="https://" aria-label="Адрес ссылки" style="width:120px"><button id="link">Ссылка</button><button data-command="unlink">Убрать ссылку</button>
</div><div id="editor" contenteditable="true" role="textbox" aria-multiline="true"></div><script>
const editor=document.getElementById('editor');editor.innerHTML=new TextDecoder().decode(Uint8Array.from(atob('$encoded'),c=>c.charCodeAt(0)));
let savedRange;document.addEventListener('selectionchange',function(){const selection=window.getSelection();if(selection.rangeCount&&editor.contains(selection.anchorNode))savedRange=selection.getRangeAt(0).cloneRange();});
function format(command,value){editor.focus();if(savedRange){const selection=window.getSelection();selection.removeAllRanges();selection.addRange(savedRange);}document.execCommand(command,false,value||null);}
document.querySelectorAll('[data-command]').forEach(button=>{button.addEventListener('mousedown',e=>e.preventDefault());button.onclick=()=>format(button.dataset.command);});
document.getElementById('link').onclick=function(){const url=document.getElementById('linkValue').value;if(url&&/^https?:\\/\\//i.test(url))format('createLink',url);};
editor.addEventListener('paste',function(event){event.preventDefault();document.execCommand('insertText',false,event.clipboardData.getData('text/plain'));});
window.saveDescription=function(){Description.postMessage(JSON.stringify({type:'save',html:editor.innerHTML}));};Description.postMessage(JSON.stringify({type:'ready'}));
</script></body></html>''';
}
