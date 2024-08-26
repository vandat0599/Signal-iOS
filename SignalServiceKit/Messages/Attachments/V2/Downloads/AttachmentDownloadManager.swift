//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

public enum AttachmentDownloads {

    public static let attachmentDownloadProgressNotification = Notification.Name("AttachmentDownloadProgressNotification")

    /// Key for a CGFloat progress value from 0 to 1
    public static var attachmentDownloadProgressKey: String { "attachmentDownloadProgressKey" }

    /// Key for a ``Attachment.IdType`` value.
    public static var attachmentDownloadAttachmentIDKey: String { "attachmentDownloadAttachmentIDKey" }

    public struct DownloadMetadata: Equatable {
        public let mimeType: String
        public let cdnNumber: UInt32
        public let encryptionKey: Data
        public let source: Source

        public enum Source: Equatable {
            case transitTier(cdnKey: String, digest: Data, plaintextLength: UInt32?)
            case mediaTierFullsize(mediaName: String, digest: Data, plaintextLength: UInt32?)
            case mediaTierThumbnail(mediaName: String)
        }

        public var digest: Data? {
            switch source {
            case .transitTier(_, let digest, _):
                return digest
            case .mediaTierFullsize(_, let digest, _):
                return digest
            case .mediaTierThumbnail:
                // No digest for media tier thumbnails; they come from the local user.
                return nil
            }
        }

        public var plaintextLength: UInt32? {
            switch source {
            case .transitTier(_, _, let plaintextLength):
                return plaintextLength
            case .mediaTierFullsize(_, _, let plaintextLength):
                return plaintextLength
            case .mediaTierThumbnail:
                // Thumbnails don't include a length out of band.
                // They may be padded with 0s to hit bucket sizes, but
                // we take advantage of the fact that jpegs support
                // no-op trailing 0s (and all thumbnails are jpegs).
                return nil
            }
        }

        public init(
            mimeType: String,
            cdnNumber: UInt32,
            encryptionKey: Data,
            source: Source
        ) {
            self.mimeType = mimeType
            self.cdnNumber = cdnNumber
            self.encryptionKey = encryptionKey
            self.source = source
        }
    }
}

public protocol AttachmentDownloadManager {

    func downloadBackup(
        metadata: BackupReadCredential
    ) -> Promise<URL>

    func downloadTransientAttachment(
        metadata: AttachmentDownloads.DownloadMetadata
    ) -> Promise<URL>

    func enqueueDownloadOfAttachmentsForMessage(
        _ message: TSMessage,
        priority: AttachmentDownloadPriority,
        tx: DBWriteTransaction
    )

    func enqueueDownloadOfAttachmentsForStoryMessage(
        _ message: StoryMessage,
        priority: AttachmentDownloadPriority,
        tx: DBWriteTransaction
    )

    func enqueueDownloadOfAttachment(
        id: Attachment.IDType,
        priority: AttachmentDownloadPriority,
        source: QueuedAttachmentDownloadRecord.SourceType,
        tx: DBWriteTransaction
    )

    /// Starts downloading off the persisted queue, if there's anything to download
    /// and if not already downloading the max number of parallel downloads at once.
    func beginDownloadingIfNecessary()

    func cancelDownload(for attachmentId: Attachment.IDType, tx: DBWriteTransaction)

    func downloadProgress(for attachmentId: Attachment.IDType, tx: DBReadTransaction) -> CGFloat?
}

extension AttachmentDownloadManager {

    public func enqueueDownloadOfAttachmentsForMessage(
        _ message: TSMessage,
        tx: DBWriteTransaction
    ) {
        enqueueDownloadOfAttachmentsForMessage(message, priority: .default, tx: tx)
    }

    public func enqueueDownloadOfAttachmentsForStoryMessage(
        _ message: StoryMessage,
        tx: DBWriteTransaction
    ) {
        enqueueDownloadOfAttachmentsForStoryMessage(message, priority: .default, tx: tx)
    }
}
