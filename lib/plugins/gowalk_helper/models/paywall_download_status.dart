enum PaywallDownloadStatus {
  loading,
  error,
  loaded;

  factory PaywallDownloadStatus.fromString(String status) {
    switch (status) {
      case "loading":
        return PaywallDownloadStatus.loading;
      case "error":
        return PaywallDownloadStatus.error;
      case "loaded":
        return PaywallDownloadStatus.loaded;
      default:
        throw ArgumentError("Couldn't parse status \"$status\"");
    }
  }
}
