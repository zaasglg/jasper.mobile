const memberRoles = {
  'SUPER_ADMIN': 'Суперадмин',
  'ADMIN': 'Администратор',
  'EXECUTOR': 'Участник',
};
String memberRoleLabel(String value) =>
    value == 'OWNER' ? 'Владелец' : memberRoles[value] ?? value;
