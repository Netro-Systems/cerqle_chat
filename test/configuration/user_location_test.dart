import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'CerqleLocation maps strongly-typed location fields into standard webchat keys',
      () {
    const location = CerqleLocation(
      country: 'Bangladesh',
      countryCode: 'BD',
      city: 'Dhaka',
      region: 'Dhaka Division',
      latitude: 23.8103,
      longitude: 90.4125,
      pageTitle: 'Cerqle - Pricing',
      pageUrl: 'https://cerqle.com/pricing',
    );

    final map = location.toMap();

    expect(map['webchat_country'], 'Bangladesh');
    expect(map['webchat_country_code'], 'BD');
    expect(map['webchat_city'], 'Dhaka');
    expect(map['webchat_region'], 'Dhaka Division');
    expect(map['webchat_lat'], 23.8103);
    expect(map['webchat_lon'], 90.4125);
    expect(map['webchat_page_title'], 'Cerqle - Pricing');
    expect(map['webchat_page_url'], 'https://cerqle.com/pricing');
  });

  test('CerqleUser merges location fields into resolvedCustomFields', () {
    const user = CerqleUser(
      name: 'Alice',
      email: 'alice@example.com',
      location: CerqleLocation(
        country: 'United Kingdom',
        countryCode: 'GB',
        city: 'London',
        latitude: 51.5074,
        longitude: -0.1278,
      ),
      customFields: {'vip_member': true, 'account_id': 1234},
    );

    final resolved = user.resolvedCustomFields;
    expect(resolved, isNotNull);
    expect(resolved!['webchat_country'], 'United Kingdom');
    expect(resolved['webchat_country_code'], 'GB');
    expect(resolved['webchat_city'], 'London');
    expect(resolved['webchat_lat'], 51.5074);
    expect(resolved['webchat_lon'], -0.1278);
    expect(resolved['vip_member'], isTrue);
    expect(resolved['account_id'], 1234);
  });
}
