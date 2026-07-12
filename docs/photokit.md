# PhotoKit provider

`photos list` uses Apple's public PhotoKit API on macOS 14 and later. It emits stable local asset identifiers, media type, dates, dimensions, favorite and hidden flags, and user-album membership without requesting image data. Source facts are nested under `facts`; the separate `observations` array is reserved for later derived OCR or classification and is empty in this provider.

`photos authorization` reports the current read/write-library authorization state without requesting access. Limited-library authorization returns only the assets the operator selected.

PhotoKit does not expose a reliable local-versus-iCloud availability fact without attempting a media request, so `availability` is `unknown`. The CLI does not request pixels, thumbnails, resources, network access, or iCloud downloads. Original filenames are read from PhotoKit resource metadata when available.

`--degraded-filesystem` preserves the older bounded package walk for compatibility. Every such row has `provenance.degraded = true`, lacks PhotoKit-only facts such as hidden state and dimensions, and may require Full Disk Access. This fallback depends on package layout and can vary across macOS releases.
