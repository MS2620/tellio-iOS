/// iOS has no Top Shelf. The shared code calls this after watch history, My List or
/// live scores change, so it stays as a no-op here.
enum TopShelfPublisher {
    static func publish() {}
}
