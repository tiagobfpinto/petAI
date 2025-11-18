import 'pet_state.dart';
import 'user_session.dart';

class SessionBootstrap {
  const SessionBootstrap({
    required this.user,
    required this.pet,
    required this.needInterestsSetup,
  });

  final UserSession user;
  final PetState pet;
  final bool needInterestsSetup;
}
