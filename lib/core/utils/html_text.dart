import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

/// Readable text for web-authored descriptions, without changing stored HTML.
String htmlToPlainText(String source) {
  final fragment = html.parseFragment(source);
  final output = StringBuffer();
  const blocks = {
    'p',
    'div',
    'section',
    'article',
    'blockquote',
    'pre',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'ul',
    'ol',
    'li',
    'tr',
  };
  void visit(dom.Node node) {
    if (node is dom.Text) {
      output.write(node.data);
    } else if (node is dom.Element) {
      final tag = node.localName;
      if (const {'script', 'style', 'template', 'noscript'}.contains(tag)) {
        return;
      }
      if (tag == 'br') {
        output.write('\n');
        return;
      }
      if (blocks.contains(tag)) output.write('\n');
      if (tag == 'li') output.write('• ');
      for (final child in node.nodes) {
        visit(child);
      }
      if (blocks.contains(tag)) output.write('\n');
      if (tag == 'td' || tag == 'th') output.write(' ');
    }
  }

  for (final node in fragment.nodes) {
    visit(node);
  }
  return output
      .toString()
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'[\t\r\f ]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
