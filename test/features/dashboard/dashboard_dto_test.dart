import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/data/models/dashboard_layout_dto.dart';
import 'package:jospar/features/dashboard/data/models/dashboard_widget_slot_dto.dart';
import 'package:jospar/features/dashboard/data/models/dashboard_widget_options_dto.dart';
import 'package:jospar/features/dashboard/domain/entities/dashboard_layout.dart';
import 'package:jospar/features/dashboard/domain/entities/dashboard_widget_slot.dart';
import 'package:jospar/features/dashboard/domain/entities/dashboard_widget_options.dart';
import 'package:jospar/features/dashboard/domain/entities/dashboard_widget_definition.dart';
import 'package:jospar/features/dashboard/presentation/utils/dashboard_options_changes.dart';

void main() {
  test('all known options map to typed fields and unknown keys survive', () {
    const entity = DashboardWidgetOptions(
      mode: 'epic',
      projectId: 'p',
      projectIds: ['p'],
      teamProjectId: 'q',
      teamProjectIds: ['q'],
      resourceProjectId: 'r',
      resourceFilterType: 'labels',
      resourceLabelKeys: ['label'],
      resourceEpicIds: ['epic'],
      resourceNames: ['pair'],
      resourceModeByProject: {'p': 'selected'},
      resourceNamesByProject: {
        'p': ['pair'],
      },
      unknownOptions: {
        'future': {'keep': true},
      },
    );
    final dto = DashboardWidgetOptionsDto.fromEntity(entity);
    expect(dto.toEntity(), entity);
    expect(DashboardWidgetOptionsDto.fromJson(dto.toJson()), dto);
    expect(dto.toJson()['resourceModeByProject'], {'p': 'selected'});
    expect(dto.toEntity().unknownOptions, {
      'future': {'keep': true},
    });
    expect(
      entity.copyWith(mode: 'column').unknownOptions,
      entity.unknownOptions,
    );
    expect(
      DashboardWidgetOptionsDto.fromJson({}).toEntity(),
      const DashboardWidgetOptions(),
    );
    expect(
      DashboardWidgetOptionsDto.fromJson({
        'projectIds': [123],
        'projectId': 42,
      }).toEntity().projectIds,
      ['123'],
    );
  });
  test(
    'slot separates metadata, normalizes API fields and retains unknown options',
    () {
      final dto = DashboardWidgetSlotDto.fromJson({
        'id': 'resource',
        'instanceId': 'r',
        'visible': false,
        'size': 'invalid',
        'height': 100,
        'mode': 'epic',
        'custom': 'keep',
      });
      final slot = dto.toEntity();
      expect(slot.size, 'half');
      expect(slot.height, 180);
      expect(slot.visible, isFalse);
      expect(slot.options.mode, 'epic');
      expect(slot.options.unknownOptions, {'custom': 'keep'});
      expect(DashboardWidgetSlotDto.fromEntity(slot).toEntity(), slot);
      expect(
        DashboardWidgetSlotDto.fromEntity(slot).toJson()['custom'],
        'keep',
      );
      expect(
        DashboardWidgetSlotDto.fromJson({
          'id': 123,
          'visible': null,
        }).instanceId,
        '123',
      );
      expect(DashboardWidgetSlotDto.fromJson({'height': 1200}).height, 900);
      expect(
        () => DashboardWidgetSlotDto.fromJson({'height': 'bad'}),
        throwsA(isA<TypeError>()),
      );
    },
  );
  test(
    'layout handles JSON wrappers, duplicate instances and unknown preferences',
    () {
      final json = {
        'layout': {
          'version': 1,
          'widgets': [
            {'id': 'resource', 'instanceId': 'r', 'custom': true},
            {'id': 'resource', 'instanceId': 'r'},
            {'id': ''},
            false,
          ],
          'layouts': {
            'xl': [
              {'i': 'r', 'customGrid': true},
            ],
          },
          'future': {'keep': true},
        },
      };
      final dto = DashboardLayoutDto.parse(jsonEncode(json));
      final layout = dto.toEntity();
      expect(layout.widgets.where((w) => w.instanceId == 'r').length, 1);
      expect(layout.unknownExtra, {
        'future': {'keep': true},
      });
      expect(layout.layouts['xl'], [
        {'i': 'r', 'customGrid': true},
      ]);
      expect(DashboardLayoutDto.fromEntity(layout).toEntity(), layout);
      final serialized = DashboardLayoutDto.fromEntity(layout).toJson();
      expect(serialized['version'], 2);
      expect(serialized['future'], {'keep': true});
      expect(DashboardLayoutDto.parse(serialized).toEntity(), layout);
      final updated = layout.withWidgets(layout.widgets);
      expect(updated.layouts['xl'], layout.layouts['xl']);
    },
  );
  test(
    'legacy/null config defaults and malformed JSON behavior are preserved',
    () {
      for (final value in <dynamic>[
        null,
        '',
        'null',
        {},
        {'widgets': 'bad'},
        {'layout': null},
      ]) {
        expect(
          DashboardLayoutDto.parse(value).toEntity(),
          DashboardLayout.defaults(),
        );
      }
      expect(() => DashboardLayoutDto.parse('{broken'), throwsFormatException);
      expect(DashboardLayoutDto.parse([]).toEntity().widgets, isNotEmpty);
    },
  );
  test(
    'explicit patch preserves normalization and can clear optional options',
    () {
      const slot = DashboardWidgetSlot(
        id: 'resource',
        instanceId: 'r',
        height: 300,
        options: DashboardWidgetOptions(
          projectId: 'p',
          mode: 'epic',
          unknownOptions: {'custom': true},
        ),
      );
      final patched = patchDashboardSlot(slot, {
        'size': 'bad',
        'visible': null,
        'height': 1200,
        'projectId': null,
        'projectIds': ['q'],
        'future': 42,
      });
      expect(patched.size, 'half');
      expect(patched.visible, isTrue);
      expect(patched.height, 900);
      expect(patched.options.projectId, isNull);
      expect(patched.options.projectIds, ['q']);
      expect(patched.options.mode, 'epic');
      expect(patched.options.unknownOptions, {'custom': true, 'future': 42});
      expect(patchDashboardSlot(patched, {'height': null}).height, isNull);
    },
  );
  test('widget definitions stay pure and support equality/copy', () {
    final definition = DashboardWidgetDefinition.find('resource')!;
    expect(definition.copyWith(), definition);
    expect(definition.duplicable, isTrue);
    expect(definition.copyWith(title: 'Other').rows, definition.rows);
    expect(DashboardWidgetDefinition.find('calendar')!.available, isFalse);
  });
}
