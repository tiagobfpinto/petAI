import 'pet_state.dart';
import 'user_session.dart';

class SessionBootstrap {
  const SessionBootstrap({
    required this.user,
    required this.pet,
    required this.needInterestsSetup,
    this.token,
  });

  final UserSession user;
  final PetState pet;
  final bool needInterestsSetup;
  final String? token;
}
