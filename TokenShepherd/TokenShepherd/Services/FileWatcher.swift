import Foundation

// MARK: - File Watcher using DispatchSource

class FileWatcher {
    typealias ChangeHandler = () -> Void

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let path: String
    private let handler: ChangeHandler

    init(path: String, handler: @escaping ChangeHandler) {
        self.path = path
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        guard source == nil else { return }

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("FileWatcher: Failed to open file at \(path)")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )

        source?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.handler()
            }
        }

        source?.setCancelHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}

// MARK: - Directory Watcher for Multiple Files

class DirectoryWatcher {
    typealias ChangeHandler = (String) -> Void

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let directoryPath: String
    private let fileExtensions: Set<String>
    private let handler: ChangeHandler
    private var lastModifiedTimes: [String: Date] = [:]

    init(directoryPath: String, fileExtensions: [String], handler: @escaping ChangeHandler) {
        self.directoryPath = directoryPath
        self.fileExtensions = Set(fileExtensions)
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        guard source == nil else { return }

        fileDescriptor = open(directoryPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("DirectoryWatcher: Failed to open directory at \(directoryPath)")
            return
        }

        // Initialize modification times
        updateModificationTimes()

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write],
            queue: DispatchQueue.global(qos: .utility)
        )

        source?.setEventHandler { [weak self] in
            self?.checkForChanges()
        }

        source?.setCancelHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func updateModificationTimes() {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directoryPath) else { return }

        for filename in contents {
            let ext = (filename as NSString).pathExtension
            if fileExtensions.contains(ext) || fileExtensions.isEmpty {
                let filePath = (directoryPath as NSString).appendingPathComponent(filename)
                if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                   let modDate = attrs[.modificationDate] as? Date {
                    lastModifiedTimes[filePath] = modDate
                }
            }
        }
    }

    private func checkForChanges() {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directoryPath) else { return }

        for filename in contents {
            let ext = (filename as NSString).pathExtension
            if fileExtensions.contains(ext) || fileExtensions.isEmpty {
                let filePath = (directoryPath as NSString).appendingPathComponent(filename)
                if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                   let modDate = attrs[.modificationDate] as? Date {
                    let lastMod = lastModifiedTimes[filePath]
                    if lastMod == nil || modDate > lastMod! {
                        lastModifiedTimes[filePath] = modDate
                        DispatchQueue.main.async { [weak self] in
                            self?.handler(filePath)
                        }
                    }
                }
            }
        }
    }
}
