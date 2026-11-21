import 'package:flauncher/desktop/desktop_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DesktopItem _item(String id, int w, int h) => DesktopItem(id: id, type: DesktopWidgetType.clock, width: w, height: h);

void main() {
  test('widgets fill the page row by row and leftovers are left out', () {
    final cells = layoutDesktopPage([_item('a', 2, 2), _item('b', 1, 1), _item('c', 1, 1), _item('d', 2, 1), _item('e', 1, 1)]);
    expect((cells['a']!.x, cells['a']!.y), (0, 0));
    expect((cells['b']!.x, cells['b']!.y), (2, 0));
    expect((cells['c']!.x, cells['c']!.y), (3, 0));
    expect((cells['d']!.x, cells['d']!.y), (2, 1));
    expect(cells.containsKey('e'), isFalse);
  });

  test('a new desktop starts with a clock', () async {
    SharedPreferences.setMockInitialValues({});
    final service = DesktopService(await SharedPreferences.getInstance());
    expect(service.pages.single.single.type, DesktopWidgetType.clock);
  });

  test('adding to a full page puts the widget on a new page after it', () async {
    SharedPreferences.setMockInitialValues({'desktop_pages': '[[{"id":"a","type":"clock","w":4,"h":2}]]'});
    final prefs = await SharedPreferences.getInstance();
    final service = DesktopService(prefs);
    final page = await service.addItem(0, DesktopWidgetType.app, size: (1, 1), ref: 'pkg');
    expect(page, 1);
    expect(service.pages.length, 2);
    expect(DesktopService(prefs).pages[1].single.ref, 'pkg');
  });

  test('moving past the end of a page moves to the next page', () async {
    SharedPreferences.setMockInitialValues({
      'desktop_pages': '[[{"id":"a","type":"clock","w":1,"h":1},{"id":"b","type":"clock","w":1,"h":1}],[]]',
    });
    final service = DesktopService(await SharedPreferences.getInstance());
    expect(await service.moveItem('a', 1), isTrue);
    expect(service.pages[0].map((i) => i.id), ['b', 'a']);
    expect(await service.moveItem('a', 1), isTrue);
    expect(service.locate('a'), (1, 0));
    expect(await service.moveItem('a', 1), isFalse);
  });

  test('only sizes that keep every widget on the page are offered', () async {
    SharedPreferences.setMockInitialValues({
      'desktop_pages': '[[{"id":"a","type":"clock","w":2,"h":2},{"id":"b","type":"clock","w":1,"h":1}]]',
    });
    final service = DesktopService(await SharedPreferences.getInstance());
    expect(service.sizesThatFit('b'), [(1, 1), (2, 1), (2, 2)]);
  });
}
