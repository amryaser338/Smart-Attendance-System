import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/courses_api.dart';
import '../domain/course_models.dart';
import 'courses_state.dart';

final coursesApiProvider = Provider((ref) => CoursesApi());

final coursesProvider =
    StateNotifierProvider<CoursesNotifier, CoursesState>((ref) {
  return CoursesNotifier(ref);
});

class CoursesNotifier extends StateNotifier<CoursesState> {
  final Ref ref;
  CoursesNotifier(this.ref) : super(const CoursesState());

  Future<void> loadForDoctor(String doctorId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final json = await ref
          .read(coursesApiProvider)
          .getDoctorCoursesSections(doctorId: doctorId);

      state = state.copyWith(
        isLoading: false,
        data: DoctorCoursesResponse.fromJson(json),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}