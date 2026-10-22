import 'package:flutter/material.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/services/news/feed.dart';
import 'package:intl/intl.dart';

String newsDate(BuildContext context, DateTime? date) => date == null
    ? ''
    : DateFormat.yMMMd(Localizations.localeOf(context).toString())
        .format(date.toLocal());
String newsTitle(BuildContext context, NewsArticle article) =>
    article.title.isEmpty
        ? AppLocalizations.of(context).newsPost
        : article.title;
