/// User-tunable configuration for a single weather source.
///
/// These let the user control polling behaviour and rate limits per service,
/// which matters because the free tiers of different providers have very
/// different call allowances.
class SourceConfig {
  const SourceConfig({
    required this.sourceId,
    this.enabled = true,
    this.apiKey,
    this.updateIntervalMinutes = 30,
    this.maxCallsPerHour = 60,
    this.maxCallsPerDay = 1000,
    this.priority = 100,
    this.timeoutSeconds = 15,
  });

  final String sourceId;

  /// Whether this source participates in fetches.
  final bool enabled;

  /// Optional API key for sources that require one.
  final String? apiKey;

  /// Minimum minutes between automatic refreshes for this source. Cached data
  /// newer than this is reused instead of triggering a network call.
  final int updateIntervalMinutes;

  /// Soft rate limit: maximum calls allowed in a rolling hour.
  final int maxCallsPerHour;

  /// Soft rate limit: maximum calls allowed in a rolling day.
  final int maxCallsPerDay;

  /// Lower number = preferred when choosing a primary value (0 is highest).
  final int priority;

  /// Per-request network timeout.
  final int timeoutSeconds;

  SourceConfig copyWith({
    bool? enabled,
    String? apiKey,
    bool clearApiKey = false,
    int? updateIntervalMinutes,
    int? maxCallsPerHour,
    int? maxCallsPerDay,
    int? priority,
    int? timeoutSeconds,
  }) {
    return SourceConfig(
      sourceId: sourceId,
      enabled: enabled ?? this.enabled,
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
      updateIntervalMinutes: updateIntervalMinutes ?? this.updateIntervalMinutes,
      maxCallsPerHour: maxCallsPerHour ?? this.maxCallsPerHour,
      maxCallsPerDay: maxCallsPerDay ?? this.maxCallsPerDay,
      priority: priority ?? this.priority,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'enabled': enabled,
        'apiKey': apiKey,
        'updateIntervalMinutes': updateIntervalMinutes,
        'maxCallsPerHour': maxCallsPerHour,
        'maxCallsPerDay': maxCallsPerDay,
        'priority': priority,
        'timeoutSeconds': timeoutSeconds,
      };

  factory SourceConfig.fromJson(Map<String, dynamic> json) => SourceConfig(
        sourceId: json['sourceId'] as String,
        enabled: json['enabled'] as bool? ?? true,
        apiKey: json['apiKey'] as String?,
        updateIntervalMinutes: json['updateIntervalMinutes'] as int? ?? 30,
        maxCallsPerHour: json['maxCallsPerHour'] as int? ?? 60,
        maxCallsPerDay: json['maxCallsPerDay'] as int? ?? 1000,
        priority: json['priority'] as int? ?? 100,
        timeoutSeconds: json['timeoutSeconds'] as int? ?? 15,
      );
}
