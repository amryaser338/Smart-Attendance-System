import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/doctor_notifier.dart';
import '../../courses/presentation/courses_sections_page.dart';

class DoctorIdPage extends ConsumerStatefulWidget {
  const DoctorIdPage({super.key});

  @override
  ConsumerState<DoctorIdPage> createState() => _DoctorIdPageState();
}

class _DoctorIdPageState extends ConsumerState<DoctorIdPage> {
  final _controller = TextEditingController(text: 'D001');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instructor Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Doctor ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final id = _controller.text.trim();
                      if (id.isEmpty) return;
                      ref.read(doctorProvider.notifier).setDoctorId(id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CoursesSectionsPage()),
                      );
                    },
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}