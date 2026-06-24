import '../domain/course_models.dart';

class CoursesState {
  final bool isLoading;
  final String? error;
  final DoctorCoursesResponse? data;

  const CoursesState({
    this.isLoading = false,
    this.error,
    this.data,
  });

  CoursesState copyWith({
    bool? isLoading,
    String? error,
    DoctorCoursesResponse? data,
  }) =>
      CoursesState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        data: data ?? this.data,
      );
}