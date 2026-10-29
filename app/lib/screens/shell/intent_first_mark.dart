import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../claim/form_recommender.dart';

const intentFirstMessage =
    'Do this first. If the VA grants your claim, pay can go back to the day they receive this form.';

bool intentFirstRow(FormSuggestion suggestion) {
  return suggestion.formNumber == '21-0966' &&
      suggestion.track == FormTrack.recommended;
}

class IntentFirstMark extends StatelessWidget {
  const IntentFirstMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: intentFirstMessage,
      child: Icon(Icons.star, color: AppColors.sand, size: 22),
    );
  }
}
