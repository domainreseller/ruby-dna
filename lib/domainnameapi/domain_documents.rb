# frozen_string_literal: true

module DomainNameApi
  # A registry document of a domain.
  class Document < Model
    field :name
    field :type, DocumentType
    field :status, DocumentStatus
    field :operation_type, DocumentOperationType
    field :uploaded_date, :time
  end

  # A file to upload as a registry document.
  #
  #   DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
  #   DomainNameApi::DocumentUpload.new(type: :passport, file_name: 'passport.jpg', content: File.binread('p.jpg'))
  class DocumentUpload < Model
    # Bytes per file.
    MAX_SIZE = 10 * 1024 * 1024
    # Bytes per request.
    MAX_UPLOAD_SIZE = 50 * 1024 * 1024
    # Accepted formats; the extension must match the file's real format.
    EXTENSIONS = %w[.pdf .jpg .jpeg .png .doc .docx .odt].freeze

    field :type, DocumentType
    # Must end in .pdf, .jpg, .jpeg, .png, .doc, .docx or .odt.
    field :file_name
    # The file content (at most MAX_SIZE bytes); it is base64-encoded for you.
    field :content, :raw

    # Reads a file into a DocumentUpload.
    def self.from_file(type, path)
      new(type: type, file_name: File.basename(path), content: File.binread(path))
    end

    def to_api
      { 'documentType' => type.respond_to?(:value) ? type.value : type, 'fileName' => Util.clean(file_name),
        'fileContent' => [content.to_s].pack('m0') }
    end

    def inspect
      "#<DomainNameApi::DocumentUpload type=#{type.inspect} file_name=#{file_name.inspect} " \
        "size=#{content.to_s.bytesize}>"
    end
  end

  # The report of an upload.
  class DocumentUploadResult < Model
    # A stored file.
    class UploadedDocument < Model
      field :name
      field :size, :integer
      field :mime_type
      field :type, DocumentType
      field :uploaded_date, :time
    end

    field :uploaded, [UploadedDocument]
    # File names that were not stored.
    field :duplicates, [:string]
    field :failed, [:string]
    field :total_document_count, :integer
    field :total_document_size, :integer
  end

  # Lists the registry documents of a domain. CLI: dna domain documents list
  class DomainDocumentsListRequest < PagedRequest
    endpoint :get, '/api/v1/domains/documents', safety: :read
    returns Page.of(Document)
    attribute :domain_name
    # Keeps only these document types (DocumentType).
    attribute :types, default: []

    def query
      params.string('DomainName', domain_name)
            .joined('DocumentTypes', Array(types).map { |t| DocumentType[t] || t })
            .page(skip: skip, limit: limit, sort: sort)
    end

    def validate
      super
      required :domain_name
      Array(types).each { |t| enum(:types, DocumentType, t) }
    end
  end

  # Uploads the documents a registry asked for (domain status
  # DomainStatus::WAITING_FOR_DOCUMENT). CLI: dna domain documents upload
  class DomainDocumentsUploadRequest < BaseRequest
    endpoint :post, '/api/v1/domains/documents', safety: :write
    returns DocumentUploadResult
    attribute :domain_name
    # DocumentUpload values (or Hashes of their fields).
    attribute :documents, default: []

    def body
      { 'domainName' => clean(domain_name), 'documents' => uploads.map(&:to_api) }
    end

    def validate
      required :domain_name
      check(!uploads.empty?, :documents, 'needs at least one value')
      total = 0
      uploads.each_with_index do |d, i|
        field = "documents[#{i}]"
        check(d.type.respond_to?(:known?) && d.type.known?, "#{field}.type", 'is not a known DocumentType')
        required "#{field}.file_name", d.file_name
        ext = File.extname(Util.clean(d.file_name)).downcase
        check(Util.blank?(d.file_name) || DocumentUpload::EXTENSIONS.include?(ext), "#{field}.file_name",
              'must be a PDF, JPG, JPEG, PNG, DOC, DOCX or ODT file')
        size = d.content.to_s.bytesize
        check(size.positive?, "#{field}.content", 'is empty')
        check(size <= DocumentUpload::MAX_SIZE, "#{field}.content", 'is larger than 10 MB')
        total += size
      end
      check(total <= DocumentUpload::MAX_UPLOAD_SIZE, :documents,
            'are larger than 50 MB together; upload them in several requests')
    end

    private

    def uploads
      Array(documents).map { |d| DocumentUpload.coerce(d) }
    end
  end

  class DomainService < Service
    # One page of a domain's registry documents.
    def documents(domain_name, **filters)
      call(DomainDocumentsListRequest.new(domain_name: domain_name, **filters))
    end

    # Uploads registry documents for a domain. Files are base64-encoded for you;
    # format and size are checked before upload.
    #
    #   doc = DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
    #   client.domains.upload_documents('example.com.tr', doc)
    def upload_documents(domain_name, *documents)
      call(DomainDocumentsUploadRequest.new(domain_name: domain_name, documents: documents.flatten))
    end
  end
end
