import '../../common/live_kit_resources.dart';
import '../../pusher/living/audience/pusher_audience_store.dart';

class PusherDebugFixtures {
  const PusherDebugFixtures._();

  static const int audienceFixtureCount = 16;

  static List<String> get comments => List<String>.generate(
        5,
        (index) => LiveKitResources.localizedString(
            'tuilivekit.debug.fixture.comment.${index + 1}'),
        growable: false,
      );

  static AudienceUser audience(int index) {
    final safeIndex = index < 0 ? 0 : index;
    final name = LiveKitResources.localizedString(
        'tuilivekit.debug.fixture.name.${safeIndex % audienceFixtureCount + 1}');
    return AudienceUser(
      userID: 'debug_audience_$safeIndex',
      userName: '$name${safeIndex + 1}',
      avatarURL: '',
      level: 1 + safeIndex % 50,
    );
  }
}
