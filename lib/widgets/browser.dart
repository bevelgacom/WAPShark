import 'package:flutter/material.dart';
import 'package:universal_image/universal_image.dart';
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;

class Browser extends StatefulWidget {
  const Browser({
    super.key,
    required this.url,
    this.backgroundColor = const Color.fromARGB(255, 52, 208, 52),
    this.textColor = const Color.fromARGB(255, 0, 0, 0)
  });
  final String url;
  final Color backgroundColor;
  final Color textColor;

  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> {
  String? _activeCard;
  XmlDocument? _document;
  late String currentURL;
  late Iterable<XmlElement> _cards;
  late String _title;
  Key _refreshKey = UniqueKey();

  late Widget view;

  @override
  void initState() {
    super.initState();
    currentURL = widget.url;
    load();
  }

  void _navigateTo(String newURL) {
    if (newURL.startsWith('#')) {
      if (newURL.length == 1) {
        return;
      }
      _activeCard = newURL.substring(1);
      _renderActiveCard();
      return;
    }
    currentURL = _relativeToAbsolute(newURL);
    load();
  }

  void _render() {
    // get all <card> elements in <wml>
    _cards = _document!.findAllElements('card');

    // get the first <card> element
    final card = _cards.first;
    _activeCard = card.getAttribute('id');
    _renderActiveCard();
  }

  void _renderActiveCard() {
    if (_activeCard == null) {
      return;
    }
    // get the <card> element with the given id
    final card = _cards.firstWhere((element) => element.getAttribute('id') == _activeCard);
    _title = card.getAttribute('title') ?? '';
    final widgets = <Widget>[];

    for (var el in card.childElements) {
      widgets.add(_xmlElementToWidget(el));
    }

    setState(() {
      view = Column(children: widgets);
      _refreshKey = UniqueKey();
    });
  }

  Widget _xmlElementToWidget(XmlElement element) {
    switch (element.name.local) {
      case 'p':
        final align = element.getAttribute('align') ?? 'left';
        var colAlign = CrossAxisAlignment.start;
        if (align == 'center') {
          colAlign = CrossAxisAlignment.center;
        } else if (align == 'right') {
          colAlign = CrossAxisAlignment.end;
        }
        var textAlignment = TextAlign.left;

        // p elements contain text mixed with other elements
        final widgets = <Widget>[];
        for (var el in element.children) {
          if (el is XmlText) {
            widgets.add(Text(el.text, textAlign: textAlignment));
          } else if (el is XmlElement) {
            widgets.add(_xmlElementToWidget(el));
          }
        }
        if (widgets.isEmpty) {
          return const SizedBox();
        }
        if (widgets.length == 1) {
          return widgets.first;
        }


        return Column(
            crossAxisAlignment: colAlign,
            children: widgets,
        );
      case 'a':
        // make a clickable link widget
        final href = element.getAttribute('href');

        return InkWell(
          onTap: () {
            _navigateTo(href ?? '#');
          },
          child: Text(
            element.text,
            style: const TextStyle(decoration: TextDecoration.underline),
          ),
        );
      case 'img':
        final src = element.getAttribute('src');
        final alt = element.getAttribute('alt');
        if (src == null) {
          return Text(alt ?? '');
        }
        return Image.network(
            _relativeToAbsolute(src),
            errorBuilder: (context, error, stackTrace) {
              return Text(alt ?? '');
            },
            color: widget.backgroundColor,
            colorBlendMode: BlendMode.modulate,
        );
      default:
        return const SizedBox();
    }
  }

  Future<void> load() async {
    // Load the URL and parse the document
    final response = await http.get(Uri.parse(currentURL));
    _document = XmlDocument.parse(response.body);
    _render();
  }

  String _relativeToAbsolute(String url) {
    // If the URL is already absolute, return it
    // this can be http://, https://, data:
    if (url.startsWith('http:') || url.startsWith('https:') || url.startsWith('data:')) {
      return url;
    }

    // if // is at the beginning, it is a protocol-relative URL
    if (url.startsWith('//')) {
      return 'http:$url';
    }

    // if / is at the beginning, it is a root-relative URL
    if (url.startsWith('/')) {
      return '${Uri.parse(widget.url).origin}$url';
    }

    // otherwise, it is a relative URL
    return '${Uri.parse(widget.url).resolve(url)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_document == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      color: widget.backgroundColor,
      child: Column(
        key: _refreshKey,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: const Divider(color: Colors.black)),
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 4.0, bottom: 4.0),
                child: Text(_title, style: TextStyle(color: widget.textColor)),
              ),
              Expanded(child: const Divider(color: Colors.black)),
            ],
          ),
          view
        ],
      ),
    );
  }
}