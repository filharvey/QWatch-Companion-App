// Custom 128-bit BLE service and characteristic UUIDs for QWatch.
// Must match the UUIDs defined in ble_service.cpp on the firmware side.
class QWatchUUIDs {
  static const service = '12345678-1234-1234-1234-123456780000';

  static const wifiSsid     = '12345678-1234-1234-1234-123456780001';
  static const wifiPassword = '12345678-1234-1234-1234-123456780002';
  static const wifiApply    = '12345678-1234-1234-1234-123456780003';
  static const steps        = '12345678-1234-1234-1234-123456780004';
  static const battery      = '12345678-1234-1234-1234-123456780005';
  static const settings     = '12345678-1234-1234-1234-123456780006';
  static const status       = '12345678-1234-1234-1234-123456780007';
  // Phone → watch: 8 bytes (uint32 unix_ts LE + int32 utc_offset_seconds LE)
  static const time         = '12345678-1234-1234-1234-123456780008';
  // Phone → watch: JSON {"t":<temp_c>,"c":<wmo_code>,"o":<utc_offset_seconds>}
  static const weather      = '12345678-1234-1234-1234-123456780009';
}
