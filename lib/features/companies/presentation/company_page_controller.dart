import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../models/company.dart';
import '../../../services/firestore_service.dart';

class CompanyPageController extends ChangeNotifier {
  CompanyPageController({
    FirestoreService? firestoreService,
    this.pageSize = 20,
  }) : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  final int pageSize;

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subscriptions = [];
  final List<List<Company>> _pages = [];
  final List<DocumentSnapshot<Map<String, dynamic>>?> _cursors = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  List<Company> get companies => [for (final page in _pages) ...page];

  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  Object? get error => _error;

  void start() {
    if (_subscriptions.isEmpty) {
      _listen(0, null);
    }
  }

  void _listen(int index, DocumentSnapshot<Map<String, dynamic>>? startAfter) {
    while (_pages.length <= index) {
      _pages.add(const <Company>[]);
      _cursors.add(null);
    }

    final stream = _service.watchCompanyPage(
      startAfter: startAfter,
      limit: pageSize,
    );

    final subscription = stream.listen(
      (snapshot) {
        _pages[index] = snapshot.docs
            .map(Company.fromFirestore)
            .toList(growable: false);
        _cursors[index] = snapshot.docs.isEmpty ? null : snapshot.docs.last;
        if (index == _pages.length - 1) {
          _hasMore = snapshot.docs.length == pageSize;
        }
        _loading = false;
        _loadingMore = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object error) {
        _error = error;
        _loading = false;
        _loadingMore = false;
        notifyListeners();
      },
    );

    if (index < _subscriptions.length) {
      _subscriptions[index].cancel();
      _subscriptions[index] = subscription;
    } else {
      _subscriptions.add(subscription);
    }
  }

  void loadMore() {
    if (_loadingMore || !_hasMore || _pages.isEmpty) {
      return;
    }
    final cursor = _cursors.last;
    if (cursor == null) {
      _hasMore = false;
      notifyListeners();
      return;
    }
    _loadingMore = true;
    notifyListeners();
    _listen(_pages.length, cursor);
  }

  Future<void> refresh() async {
    for (var index = _subscriptions.length - 1; index >= 1; index--) {
      await _subscriptions[index].cancel();
      _subscriptions.removeAt(index);
      _pages.removeAt(index);
      _cursors.removeAt(index);
    }
    _hasMore = true;
    if (_subscriptions.isEmpty) {
      _loading = true;
      notifyListeners();
      _listen(0, null);
      return;
    }
    _listen(0, null);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
