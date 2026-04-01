import Foundation

/// Progress events yielded by the import engine, consumed by the ImportViewModel.
/// Mirrors the Python import_engine.py event dicts.
enum ImportEvent {
    case start(total: Int, message: String)
    case pageStart(index: Int, pageID: String, title: String, message: String)
    case step(index: Int, step: String, message: String)
    case skip(index: Int, filename: String, message: String)
    case pageDone(index: Int, filename: String, message: String)
    case error(index: Int, message: String)
    case complete(imported: Int, skipped: Int, errors: Int, message: String)
}
