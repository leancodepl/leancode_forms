import 'package:advanced_forms_example/main.dart';
import 'package:advanced_forms_example/screens/form_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Home Page',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.simple),
            child: const Text('Simple Form'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.password),
            child: const Text('Password Form'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.delivery),
            child: const Text('Delivery List Form'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.quiz),
            child: const Text('Quiz Form'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.complex),
            child: const Text('Complex Form'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.scroll),
            child: const Text('Scroll Form'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.optimized),
            child: const Text('Optimized Rendering'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.step),
            child: const Text('Step Form'),
          ),
        ],
      ),
    );
  }
}
