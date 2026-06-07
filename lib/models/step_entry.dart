class StepEntry {
  final String date; // YYYY-MM-DD
  final int steps;

  const StepEntry({required this.date, required this.steps});

  // Parses the 105-byte BLE payload: 7 x { date[11] + uint32 } little-endian
  static List<StepEntry> fromBytes(List<int> bytes) {
    const entrySize = 15; // 11 bytes date + 4 bytes uint32
    final entries = <StepEntry>[];
    for (var i = 0; i + entrySize <= bytes.length; i += entrySize) {
      final dateBytes = bytes.sublist(i, i + 11);
      final date = String.fromCharCodes(dateBytes.where((b) => b != 0));
      final steps = bytes[i + 11] |
          (bytes[i + 12] << 8) |
          (bytes[i + 13] << 16) |
          (bytes[i + 14] << 24);
      if (date.isNotEmpty) entries.add(StepEntry(date: date, steps: steps));
    }
    return entries;
  }
}
