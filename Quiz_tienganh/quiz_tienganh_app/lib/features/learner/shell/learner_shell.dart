import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/learner_tab_index.dart';
import '../home/views/home_screen.dart';
import '../profile_progress/views/profile_progress_screen.dart';
import '../topic_list/views/topic_list_screen.dart';

/// Một route duy nhất: [IndexedStack] giữ 3 màn — đổi tab qua [LearnerTabIndex], không thay route.
class LearnerShell extends StatefulWidget {
  const LearnerShell({required this.initialTab, super.key});

  final int initialTab;

  @override
  State<LearnerShell> createState() => _LearnerShellState();
}

class _LearnerShellState extends State<LearnerShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LearnerTabIndex>().goTo(widget.initialTab);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LearnerTabIndex>(
      builder: (context, tabs, _) {
        return IndexedStack(
          index: tabs.index.clamp(0, 2),
          sizing: StackFit.expand,
          children: const [
            HomeScreen(),
            TopicListScreen(),
            ProfileProgressScreen(),
          ],
        );
      },
    );
  }
}
