import 'src/personalization_sdk.dart';
import 'src/sdk_init_config.dart';

export 'src/sdk_init_config.dart' show SdkInitConfig;
export 'src/tracking/purchase_line_item.dart' show PurchaseLineItem;

typedef PersonaclickInitConfig = SdkInitConfig;

class PersonaclickFlutterSdk extends PersonalizationSdk {}
