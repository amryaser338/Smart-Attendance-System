import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'doctor_state.dart';

final doctorProvider =
    StateNotifierProvider<DoctorNotifier, DoctorState>((ref) {
  return DoctorNotifier();
});

class DoctorNotifier extends StateNotifier<DoctorState> {
  DoctorNotifier() : super(const DoctorState());

  void setDoctorId(String id) => state = state.copyWith(doctorId: id.trim());
}