import 'package:flutter/material.dart';

/// Placeholder for the Search Students use case.
/// Will hit GET /students/search?q= once the API exists.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TextField(
          decoration: InputDecoration(
            hintText: 'Search students by name or batch',
            border: InputBorder.none,
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Start typing to find a student.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
