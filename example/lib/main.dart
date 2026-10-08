import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'src/theme/example_theme.dart';
import 'src/widgets/example_brand_header.dart';
import 'src/widgets/example_hero_card.dart';
import 'src/widgets/integration_card.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final widgetKey = dotenv.get('CERQLE_WIDGET_KEY').trim();
  final configuredOneSignalAppId =
      dotenv.maybeGet('CERQLE_ONESIGNAL_APP_ID')?.trim();
  final config = CerqleConfig(
    widgetKey: widgetKey,
    requireNotificationPermission: true,
    lightStatusBarIcons: true,
    apiBaseUrl: dotenv.maybeGet('CERQLE_API_BASE_URL')?.trim() ??
        'https://yourdomain.com',
    oneSignalAppId: configuredOneSignalAppId?.isNotEmpty == true
        ? configuredOneSignalAppId!
        : CerqleConfig.defaultOneSignalAppId,
    user: const CerqleUser(
      name: 'Demo Visitor',
      email: 'visitor@demo.com',
    ),
  );

  await CerqleChat.initialize(
    config: config,
    navigatorKey: navigatorKey,
  );

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
          actions: [
            CerqleChat.badge(
              config: config,
              showCount: true,
              largeSize: 18,
              backgroundColor: Color(0xFFFF0000),
              textStyle: TextStyle(fontSize: 10),
              offset: Offset(-6, 6),
              child: IconButton(
                iconSize: 26,
                icon: const Icon(Icons.message),
                onPressed: () async {
                  await CerqleChat.open(
                    context,
                    config: config,
                  );
                },
              ),
            )
          ],
        ),
        body: Column(
          children: [
            CerqleChat.badge(
              config: config,
              showCount: true,
              largeSize: 20,
              backgroundColor: const Color(0xFFFF0000),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              offset: const Offset(5, -5),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await CerqleChat.open(context, config: config);
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B007A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
        // body: DecoratedBox(
        //   decoration: const BoxDecoration(
        //     color: cerqleBackground,
        //   ),
        //   child: Align(
        //     alignment: Alignment.topCenter,
        //     child: ConstrainedBox(
        //       constraints: const BoxConstraints(maxWidth: 760),
        //       child: ListView(
        //         padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        //         children: [
        //           const ExampleHeroCard(),
        //           const SizedBox(height: 24),
        //           const _SectionHeader(),
        //           const SizedBox(height: 12),
        //           IntegrationCard(
        //             icon: Icons.fullscreen_rounded,
        //             title: 'Full-screen chat',
        //             subtitle: 'Open a dedicated support workspace',
        //             onTap: () => CerqleChat.open(
        //               context,
        //               config: config,
        //             ),
        //           ),
        //           const SizedBox(height: 10),
        //           IntegrationCard(
        //             icon: Icons.vertical_align_top_rounded,
        //             title: 'Bottom sheet',
        //             subtitle: 'Slide chat over the current workflow',
        //             onTap: () => CerqleChat.open(
        //               context,
        //               config: config,
        //               presentation: CerqlePresentation.bottomSheet,
        //             ),
        //           ),
        //           const SizedBox(height: 10),
        //           IntegrationCard(
        //             icon: Icons.web_asset_rounded,
        //             title: 'Dialog',
        //             subtitle: 'Launch a compact support window',
        //             onTap: () => CerqleChat.open(
        //               context,
        //               config: config,
        //               presentation: CerqlePresentation.dialog,
        //             ),
        //           ),
        //           const SizedBox(height: 10),
        //           IntegrationCard(
        //             icon: Icons.view_quilt_rounded,
        //             title: 'Embedded view',
        //             subtitle: 'Render chat inside an existing layout',
        //             onTap: () => Navigator.of(context).push<void>(
        //               MaterialPageRoute<void>(
        //                 builder: (_) => EmbeddedExample(config: config),
        //               ),
        //             ),
        //           ),
        //           const SizedBox(height: 20),
        //         ],
        //       ),
        //     ),
        //   ),
        // ),
        floatingActionButton: CerqleChatLauncher(
          config: config,
          showBadge: true,
          badgeShowCount: true,
          badgeBackgroundColor: Color(0xFFFF0000),
          badgeLargeSize: 20,
          badgeOffset: Offset(4, -4),
        ),
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
