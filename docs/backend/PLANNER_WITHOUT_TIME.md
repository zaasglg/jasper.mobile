# План на день без времени

В мобильном ежедневнике можно выбрать день, не назначая время начала. По
умолчанию формы добавления используют «Без времени». Записи выбранного дня
показываются над расписанием. Нажатие открывает выбор времени, затем обычное
редактирование длительности и подтверждение. Отмена сохраняет запись сверху.
Меню записи позволяет вернуть её из расписания в «Без времени» или изменить день.
Выполнение и архивирование исходной задачи проекта не меняются.

## Данные

- `plannedDate`: календарная дата `YYYY-MM-DD`, в PostgreSQL `DATE`.
- `scheduledAt`: UTC-момент начала либо `null`, когда время ещё не выбрано.
- Без времени запись не участвует в проверке пересечений, напоминаниях по времени
  или экспорте назначенных часов в Google Календарь.
- Старые записи без обоих полей сохраняются с подписью «Без даты». День им не
  назначается автоматически. Новые записи без времени обязательно имеют день.
- Задачи и сроки проектов не импортируются автоматически. Прежняя дедупликация
  связанной задачи сохраняется: повторное добавление изменяет её запись.

## Требуемое обновление сервера

Патч `planner-without-time.patch` применяется в `zaasglg/orbita-back` **после**
`planner-independent-lifecycle.patch`. Основа обоих изменений — коммит
`98f4a443d30d79f665d8437f144caa81639efbb5`. Изолированная рабочая копия с обоими
исправлениями находится в `.dart_tool/planner-backend` мобильного проекта.

Новые маршруты не позволяют старому серверу принять запрос, проигнорировав день:

- POST `project-planner/account/day-tasks` — личная запись.
- POST `project-planner/:projectId/day-tasks` — ссылка на задачу проекта.
- POST `project-planner/account/day-inbox-tasks` — существующее добавление из Инбокса.
- PATCH `project-planner/items/:itemId/schedule` — изменение дня и снятие времени.

На старом сервере приложение показывает ошибку обновления, сохраняя форму и
введённое название. Пользователь может явно выбрать «Указать время» и использовать
прежний маршрут. Автоматической подмены отсутствующего времени на `00:00` нет.

В рабочей копии сервера выполнить, подставив путь к мобильному проекту:

```powershell
# Если независимость выполнения ещё не установлена, сначала применить её патч.
git apply --check "C:/path/to/orbita-mobile/docs/backend/planner-independent-lifecycle.patch"
git apply "C:/path/to/orbita-mobile/docs/backend/planner-independent-lifecycle.patch"

git apply --check "C:/path/to/orbita-mobile/docs/backend/planner-without-time.patch"
git apply "C:/path/to/orbita-mobile/docs/backend/planner-without-time.patch"
npm.cmd ci
node node_modules/prisma/build/index.js generate
node node_modules/typescript/bin/tsc --noEmit --incremental false
node node_modules/jest/bin/jest.js --runInBand src/project-planner/planner-day.spec.ts src/project-planner/planner-independent-completion.spec.ts src/project-planner/planner-account.spec.ts src/project-planner/planner-inbox.spec.ts src/project-planner/planner-update-transaction.spec.ts src/project-planner/planner-list-access.spec.ts src/google-drive/google-planner-sync.spec.ts
```

Перед запуском обновлённого сервера применить миграции обычным процессом проекта:
`npm.cmd run db:deploy`. Новая миграция добавляет nullable-колонку и индекс;
существующие записи не переписываются и время им не назначается. Затем развернуть
сервер и выпустить мобильное приложение. Рабочая база и сервер этой задачей не изменялись.

Проверки используют подставной API и моки базы. Тесты проверяют дату после
перезагрузки, изоляцию дней, назначение и снятие времени, отмену выбора, перенос
дня, старый сервер и сохранение существующего планирования со временем.
