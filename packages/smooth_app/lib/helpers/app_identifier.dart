import 'package:smooth_app/database/dao_secured_string.dart'
    show DaoSecuredString;

const String _APP_IDENTIFIER_KEY = 'APP_IDENTIFIER';
Future<String?> getAppIdentifier() async {
  return DaoSecuredString.get(_APP_IDENTIFIER_KEY);
}

Future<void> setAppIdentifier(final String value) async {
  await DaoSecuredString.put(key: _APP_IDENTIFIER_KEY, value: value);
}
