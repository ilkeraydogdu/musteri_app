import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuestProfile {
  final String name;
  final String phone;
  final List<String> allergies;
  final List<String> dislikes;
  final bool askedAllergies;

  const GuestProfile({
    this.name = '',
    this.phone = '',
    this.allergies = const [],
    this.dislikes = const [],
    this.askedAllergies = false,
  });

  bool get hasIdentity => name.trim().isNotEmpty && phone.trim().length >= 10;

  GuestProfile copyWith({
    String? name,
    String? phone,
    List<String>? allergies,
    List<String>? dislikes,
    bool? askedAllergies,
  }) {
    return GuestProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      allergies: allergies ?? this.allergies,
      dislikes: dislikes ?? this.dislikes,
      askedAllergies: askedAllergies ?? this.askedAllergies,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'allergies': allergies,
        'dislikes': dislikes,
        'asked_allergies': askedAllergies,
      };

  factory GuestProfile.fromJson(Map<String, dynamic> json) {
    List<String> listOf(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      return const [];
    }

    return GuestProfile(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      allergies: listOf(json['allergies']),
      dislikes: listOf(json['dislikes']),
      askedAllergies: json['asked_allergies'] == true,
    );
  }
}

final guestProfileProvider = StateNotifierProvider<GuestProfileNotifier, GuestProfile>((ref) {
  return GuestProfileNotifier();
});

class GuestProfileNotifier extends StateNotifier<GuestProfile> {
  GuestProfileNotifier() : super(const GuestProfile()) {
    _load();
  }

  static const _key = 'qordy_guest_profile';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) state = GuestProfile.fromJson(map);
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> saveIdentity({required String name, required String phone}) async {
    state = state.copyWith(name: name.trim(), phone: phone.replaceAll(RegExp(r'\s+'), ''));
    await _save();
  }

  Future<void> setAllergies(List<String> values) async {
    state = state.copyWith(
      allergies: values.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList(),
      askedAllergies: true,
    );
    await _save();
  }

  Future<void> setDislikes(List<String> values) async {
    state = state.copyWith(
      dislikes: values.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList(),
    );
    await _save();
  }

  Future<void> learnFromMessage(String text) async {
    final lower = text.toLowerCase();
    final allergyHit = lower.contains('alerji') || lower.contains('alerjim');
    final dislikeHit = lower.contains('sevmem') || lower.contains('istemem') || lower.contains('yemem');
    if (!allergyHit && !dislikeHit) return;

    final tokens = text
        .split(RegExp(r'[,.;]| ve | ile '))
        .map((e) => e.trim())
        .where((e) => e.length > 2 && e.length < 40)
        .toList();
    if (tokens.isEmpty) return;

    if (allergyHit) {
      await setAllergies([...state.allergies, ...tokens]);
    }
    if (dislikeHit) {
      await setDislikes([...state.dislikes, ...tokens]);
    }
  }
}
