// Driver for running integration tests in a browser:
//
//   chromedriver --port=4444 &
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/demo_journeys_test.dart -d web-server
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
