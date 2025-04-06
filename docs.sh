swift package \
    --allow-writing-to-directory ./docs \
    generate-documentation --target SharedFoundation \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path shared-foundation \
    --output-path ./docs
