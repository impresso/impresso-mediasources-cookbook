# How to Update the v1.1.0 Release Notes

The v1.1.0 release has been published with minimal release notes. This guide explains how to update the release with the comprehensive notes we've created.

## Current Release Notes

The current v1.1.0 release only contains:
```
**Full Changelog**: https://github.com/impresso/impresso-make-cookbook/compare/v1.0.0...v1.1.0
```

## Comprehensive Release Notes

Detailed release notes have been prepared in `RELEASE_NOTES_v1.1.0.md` which include:
- Complete overview of the release
- All major features and enhancements
- Technical improvements
- Migration guide
- Configuration details
- Links and references

## Option 1: Update via GitHub Web Interface

1. Go to https://github.com/impresso/impresso-make-cookbook/releases/tag/v1.1.0
2. Click the **"Edit release"** button (requires appropriate permissions)
3. Copy the content from `RELEASE_NOTES_v1.1.0.md`
4. Paste it into the release description field
5. Review and save

## Option 2: Update via GitHub CLI

If you have the GitHub CLI installed and authenticated:

```bash
# Update the release with the new notes
gh release edit v1.1.0 \
  --notes-file RELEASE_NOTES_v1.1.0.md \
  --repo impresso/impresso-make-cookbook
```

## Option 3: Keep as Separate Documentation

If updating the release directly is not preferred, the comprehensive release notes are now available in the repository:

- `RELEASE_NOTES_v1.1.0.md` - Full release notes for v1.1.0
- `CHANGELOG.md` - Ongoing changelog for all releases
- `RELEASE_PROCESS.md` - Guide for creating future releases

Users can reference these files for detailed information about the release.

## Future Releases

For future releases, follow the process documented in `RELEASE_PROCESS.md`:
1. Prepare the release using the checklist
2. Write comprehensive release notes using the template
3. Create the release with detailed notes from the start
4. Update `CHANGELOG.md` for each release

## Benefits of Comprehensive Release Notes

The new release notes provide:
- **Discoverability**: Users can easily find what's new
- **Migration guidance**: Clear instructions for upgrading
- **Feature documentation**: Detailed explanation of new capabilities
- **Transparency**: Complete view of changes and improvements
- **Professional appearance**: Well-structured and comprehensive

## Questions?

If you have questions about updating the release or the release process, refer to:
- `RELEASE_PROCESS.md` for the complete release workflow
- `CHANGELOG.md` for the history of changes
- `RELEASE_NOTES_v1.1.0.md` for the full v1.1.0 release details
