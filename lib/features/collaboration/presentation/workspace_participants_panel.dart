import 'package:flutter/material.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/collaboration_models.dart';

/// Compact member directory with horizontally scrollable filters on phones.
class WorkspaceParticipantsPanel extends StatefulWidget {
  const WorkspaceParticipantsPanel({
    required this.members,
    required this.actions,
    super.key,
  });
  final List<SpaceMember> members;
  final Widget? Function(SpaceMember) actions;

  @override
  State<WorkspaceParticipantsPanel> createState() =>
      _WorkspaceParticipantsPanelState();
}

class _WorkspaceParticipantsPanelState
    extends State<WorkspaceParticipantsPanel> {
  int _tab = 0;
  String _query = '';
  static const _labels = [
    'Участники',
    'Гости одной доски',
    'Гости нескольких досок',
    'Приглашения',
  ];

  int _group(SpaceMember member) {
    if (member.access == 'INVITATION') return 3;
    if (member.access != 'GUEST' &&
        member.access != 'project' &&
        member.role != 'GUEST' &&
        member.details['isGuest'] != true) {
      return 0;
    }
    final projects = member.details['projects'];
    final count =
        member.details['projectCount'] ??
        (projects is List ? projects.length : null);
    return count is num && count > 1 ? 2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = widget.members
        .where((m) => _group(m) == _tab)
        .where((m) => '${m.name} ${m.email}'.toLowerCase().contains(_query))
        .toList();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      _labels.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _tab == index,
                          label: Text(
                            '${_labels[index]} · ${widget.members.where((m) => _group(m) == index).length}',
                          ),
                          onSelected: (_) => setState(() => _tab = index),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Поиск по имени или почте',
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Ничего не найдено', textAlign: TextAlign.center),
            ),
          for (final member in members)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    size: 40,
                    userId: member.userId.isEmpty ? null : member.userId,
                    name: member.name,
                    avatarUrl: member.avatarUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name.isEmpty ? member.email : member.name,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (member.email.isNotEmpty && member.name.isNotEmpty)
                          Text(member.email, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 6),
                        Text(
                          member.isWorkspaceOwner
                              ? 'Владелец'
                              : memberRoleLabel(member.role),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (member.details['lastActiveAt'] != null)
                          Text(
                            'Последняя активность: ${member.details['lastActiveAt']}',
                            style: theme.textTheme.bodySmall,
                          ),
                        if (member.details['projects'] is List &&
                            (member.details['projects'] as List).isNotEmpty)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              'Проекты · ${(member.details['projects'] as List).length}',
                              style: theme.textTheme.bodySmall,
                            ),
                            children: [
                              for (final project
                                  in member.details['projects'] as List)
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    project is Map
                                        ? (project['name'] ??
                                                  project['title'] ??
                                                  'Проект')
                                              .toString()
                                        : project.toString(),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (_tab != 3 && widget.actions(member) != null)
                    widget.actions(member)!,
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Всего: ${members.length}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
