import 'pet_state.dart';
import 'subscription_status.dart';
import 'user_session.dart';

class SessionBootstrap {
  const SessionBootstrap({
    required this.user,
    required this.pet,
    required this.needInterestsSetup,
    this.subscription,
    this.token,
  });

  final UserSession user;
  final PetState pet;
  final bool needInterestsSetup;
  final SubscriptionStatus? subscription;
  final String? token;
}
