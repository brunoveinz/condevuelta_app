/// Spanish (Chile) date formatting without the intl package.
library;

const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "jueves 18 de septiembre"
String formatLongDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${date.day} de ${_months[date.month - 1]}';

/// "18 de septiembre"
String formatDayMonth(DateTime date) => '${date.day} de ${_months[date.month - 1]}';

/// Human countdown for a loan's due date.
String formatDaysLeft(int daysLeft) {
  if (daysLeft < -1) return 'Venció hace ${-daysLeft} días';
  if (daysLeft == -1) return 'Venció ayer';
  if (daysLeft == 0) return 'Vence hoy';
  if (daysLeft == 1) return 'Vence mañana';
  return 'Quedan $daysLeft días';
}

/// Friendly greeting based on the time of day.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Buenos días';
  if (now.hour < 20) return 'Buenas tardes';
  return 'Buenas noches';
}
