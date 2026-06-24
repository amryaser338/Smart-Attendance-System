class DoctorState {
  final String doctorId;

  const DoctorState({this.doctorId = ''});

  DoctorState copyWith({String? doctorId}) =>
      DoctorState(doctorId: doctorId ?? this.doctorId);
}