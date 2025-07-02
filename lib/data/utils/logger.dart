import 'package:logger/logger.dart';

late Logger logger;

Future<void> initLogger() async {
  logger = Logger(
    printer: PrettyPrinter(
      colors: false,
      methodCount: 2,
      lineLength: 200,
      noBoxingByDefault: true,
    ),
    output: MultiOutput([ConsoleOutput()]),
  );
  logger.d('First logger message 🛟');
}
