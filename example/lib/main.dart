import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cerqle_chat/cerqle_chat.dart';

import 'src/example_media_adapter.dart';
import 'src/theme/example_theme.dart';
import 'src/widgets/example_brand_header.dart';
import 'src/widgets/example_hero_card.dart';
import 'src/widgets/integration_card.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final widgetKey = dotenv.get('CERQLE_WIDGET_KEY').trim();
  final config = CerqleConfig(
    widgetKey: widgetKey,
    // requireNotificationPermission: true,
    lightStatusBarIcons: true,
    apiBaseUrl:
        dotenv.maybeGet('CERQLE_API_BASE_URL')?.trim() ?? 'https://cerqle.ai',
    mediaAdapter: ExampleMediaAdapter(),
    user: const CerqleUser(
      name: 'Demo Visitor',
      email: 'visitor@demo.com',
      location: CerqleLocation(
        country: 'Bangladesh',
        countryCode: 'BD',
        city: 'Dhaka',
        region: 'Dhaka Division',
        latitude: 23.8103,
        longitude: 90.4125,
        pageTitle: 'Cerqle Example App',
        pageUrl: 'cerqle://example',
      ),
    ),
  );

  // 1. Initialize push notification handlers
  CerqleChat.initializeNotificationHandlers(
    config: config,
    navigatorKey: navigatorKey,
  );

  // 2. Register live visitor presence in background
  unawaited(CerqleChat.registerVisitor(config: config));

  runApp(
    ExampleApp(config: config),
  );
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.config});

  final CerqleConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Cerqle Chat',
        theme: buildExampleTheme(),
        home: ExampleHome(config: config),
      );
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key, required this.config});

  final CerqleConfig config;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: 24,
          title: const ExampleBrandHeader(),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: cerqleBorder),
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            color: cerqleBackground,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                children: [
                  const ExampleHeroCard(),
                  const SizedBox(height: 24),
                  const _SectionHeader(),
                  const SizedBox(height: 12),
                  IntegrationCard(
                    icon: Icons.fullscreen_rounded,
                    title: 'Full-screen chat',
                    subtitle: 'Open a dedicated support workspace',
                    onTap: () => CerqleChat.open(
                      context,
                      config: config,
                    ),
                  ),
                  const SizedBox(height: 10),
                  IntegrationCard(
                    icon: Icons.vertical_align_top_rounded,
                    title: 'Bottom sheet',
                    subtitle: 'Slide chat over the current workflow',
                    onTap: () => CerqleChat.open(
                      context,
                      config: config,
                      presentation: CerqlePresentation.bottomSheet,
                    ),
                  ),
                  const SizedBox(height: 10),
                  IntegrationCard(
                    icon: Icons.web_asset_rounded,
                    title: 'Dialog',
                    subtitle: 'Launch a compact support window',
                    onTap: () => CerqleChat.open(
                      context,
                      config: config,
                      presentation: CerqlePresentation.dialog,
                    ),
                  ),
                  const SizedBox(height: 10),
                  IntegrationCard(
                    icon: Icons.view_quilt_rounded,
                    title: 'Embedded view',
                    subtitle: 'Render chat inside an existing layout',
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => EmbeddedExample(config: config),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: CerqleChatLauncher(config: config),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(
            child: Text(
              'Integration modes',
              style: TextStyle(
                color: cerqleTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '4 options',
            style: TextStyle(
              color: cerqleTextMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class EmbeddedExample extends StatelessWidget {
  const EmbeddedExample({super.key, required this.config});

  final CerqleConfig config;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Embedded chat',
          ),
          backgroundColor: Color(0xFF3E2A49),
          titleSpacing: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: CerqleChatView(config: config),
          ),
        ),
      );
}
