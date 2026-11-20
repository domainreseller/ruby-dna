# frozen_string_literal: true

module DomainNameApi
  # --- Domains ----------------------------------------------------------------

  # Lifecycle state of a domain.
  class DomainStatus < Enum
    member :active, 0
    member :waiting_for_registration, 1
    member :waiting_for_document, 2, description: 'registry documents must be uploaded (domains.upload_documents)'
    member :waiting_for_incoming_transfer, 3, description: 'internal transfer from another reseller'
    member :transferred_out, 4, description: 'moved to another registrar'
    member :transfer_rejected, 5, description: 'an incoming transfer was rejected'
    member :pending_delete, 7, description: 'in the redemption period; domains.restore may bring it back'
    member :deleted, 8
    member :confirmation_email_send, 9, description: 'transfer confirmation e-mail sent'
    member :waiting_for_outgoing_transfer, 11, description: 'transfer to another registrar in progress'
    member :pending_hold, 12, description: 'suspended, e.g. the registrant e-mail was not verified in 15 days'
    member :modification_pending, 15
    member :in_case, 18, description: 'subject to a legal process'
    member :pending_restore, 19
  end

  # A contact role. A registration needs all four.
  class ContactType < Enum
    member :registrant, 'Registrant', aliases: %w[owner], description: 'the domain owner'
    member :admin, 'Admin', aliases: %w[administrative]
    member :tech, 'Tech', aliases: %w[technical]
    member :billing, 'Billing'
  end

  # A URL forwarding mode.
  class ForwardType < Enum
    member :standard, 'Standard', aliases: %w[redirect 301], description: 'HTTP 301 redirect'
    member :frame, 'Frame', aliases: %w[masked], description: 'shows the target in a frame (masked URL)'
  end

  # What to do with DNSSEC when the nameservers of a signed domain change.
  class DNSSECMode < Enum
    member :block, 0, description: 'reject the change while DS records exist (the default)'
    member :keep, 1, name: 'KeepDnssec', description: 'keep the DS records: the new DNS provider serves a matching DNSKEY'
    member :disable, 2, name: 'DisableDnssec', description: 'remove all DS records first, then change the nameservers'
  end

  # IP version of a child nameserver address.
  class IPVersion < Enum
    member :v4, 'v4', aliases: %w[ipv4 4]
    member :v6, 'v6', aliases: %w[ipv6 6], description: 'rejected when the TLD has no IPv6 glue'
  end

  # --- Documents --------------------------------------------------------------

  # Kind of a registry document (mostly for .tr domains).
  class DocumentType < Enum
    member :identity_card, 1
    member :passport, 2
    member :tax_certificate, 3
    member :activity_certificate, 4
    member :signature_circular, 5
    member :authorization_letter, 6
    member :petition, 7
    member :trade_registry_gazette, 8
    member :trademark_certificate, 9
    member :education_certificate, 10, description: '.edu.tr'
    member :organization_statute, 11, description: '.org.tr'
    member :government_approval, 12, description: '.gov.tr, .bank, .mil.tr'
    member :domain_ownership_proof, 13
    member :power_of_attorney, 14
    member :bar_association_certificate, 15, description: '.av.tr'
    member :medical_diploma_or_license, 16, description: '.dr.tr'
    member :municipal_official_letter, 17, description: '.bel.tr'
    member :education_institution_license, 18, description: '.k12.tr, .edu.tr'
    member :chamber_of_commerce_certificate, 19
    member :trademark_transfer_agreement, 20
    member :kep_authorization, 21, description: '.kep.tr'
    member :other, 99
  end

  # Review state of a registry document.
  class DocumentStatus < Enum
    member :waiting, 1, description: 'expected, not uploaded'
    member :pending, 2, description: 'uploaded, not reviewed yet'
    member :approved, 3
    member :rejected, 4
    member :expired, 5
    member :cancelled, 6, description: 'application or owner change cancelled'
  end

  # The operation a document was requested for.
  class DocumentOperationType < Enum
    member :create, 1, description: 'new registration'
    member :owner_change, 2, description: 'trade / registrant change'
    member :delete, 3
  end

  # --- DNS and DNSSEC ---------------------------------------------------------

  # A DNS record type. The API is case-sensitive about it; requests fix the case
  # for you ("txt" is sent as "TXT", "dnskey" as "DNSKey").
  class RecordType < Enum
    member :a, 'A'
    member :aaaa, 'AAAA'
    member :alias, 'ALIAS', description: 'a CNAME-like record allowed at the apex'
    member :ns, 'NS'
    member :cname, 'CNAME', description: 'needs a name: not allowed at the apex'
    member :mx, 'MX', description: 'content is "PRIORITY HOST", e.g. "10 mail.example.com"'
    member :soa, 'SOA'
    member :txt, 'TXT', description: 'the API adds the surrounding quotes'
    member :ptr, 'PTR'
    member :srv, 'SRV'
    member :dnskey, 'DNSKey'
    member :ds, 'DS'
    member :nsec, 'NSEC'
    member :nsec3, 'NSEC3'
    member :nsec3param, 'NSEC3Param'
    member :rrsig, 'RRSIG'
    member :afsdb, 'AFSDB'
    member :atma, 'ATMA'
    member :caa, 'CAA', description: 'content has exactly 3 parts: 0 issue "letsencrypt.org"'
    member :cert, 'CERT'
    member :dhcid, 'DHCID'
    member :dname, 'DName'
    member :hinfo, 'HInfo'
    member :isdn, 'ISDN'
    member :loc, 'LOC'
    member :mb, 'MB'
    member :mg, 'MG'
    member :minfo, 'MInfo'
    member :mr, 'MR'
    member :naptr, 'NAPTR'
    member :nsap, 'NSAP'
    member :rp, 'RP'
    member :rt, 'RT'
    member :tlsa, 'TLSA'
    member :x25, 'X25'
  end

  # DNSSEC state of a domain.
  class DNSSECStatus < Enum
    member :unsigned, 0, description: 'no DS record at the registry'
    member :pending_enable, 1, description: 'DS add sent, awaiting confirmation'
    member :signed, 2, description: 'at least one active DS record'
    member :pending_disable, 3, description: 'DS removal sent, awaiting confirmation'
    member :error, 4, description: 'the last DNSSEC operation failed'
  end

  # Kind of a DNSSEC operation.
  class DNSSECOperationType < Enum
    member :add, 0
    member :remove, 1
    member :remove_all, 2
    member :sync, 3
  end

  # State of a DS record. Several can be active during a key rollover.
  class DSRecordStatus < Enum
    member :pending, 0
    member :active, 1
    member :removing, 2
    member :removed, 3
    member :failed, 4
  end

  # IANA DNSSEC algorithm number.
  class DNSSECAlgorithm < Enum
    member :rsa_md5, 1
    member :dsa, 3
    member :rsa_sha1, 5
    member :dsa_nsec3_sha1, 6
    member :rsa_sha1_nsec3_sha1, 7
    member :rsa_sha256, 8
    member :rsa_sha512, 10
    member :ecc_gost, 12
    member :ecdsa_p256_sha256, 13
    member :ecdsa_p384_sha384, 14
    member :ed25519, 15
    member :ed448, 16
  end

  # IANA DS digest type.
  class DSDigestType < Enum
    member :sha1, 1
    member :sha256, 2
    member :gost, 3
    member :sha384, 4
  end

  # --- SSL --------------------------------------------------------------------

  # Domain control validation method of a certificate.
  class AuthenticationType < Enum
    member :email, 'Email', description: 'approval e-mail to the approver address'
    member :cname, 'Cname', description: 'DNS CNAME record'
    member :http, 'Http', description: 'HTTP file on the site'
    member :file, 'File', description: 'file-based validation'
  end

  # Web server software a certificate is issued for.
  class WebServerType < Enum
    member :apache, 'Apache'
    member :iis, 'IIS'
    member :aol, 'AOL'
    member :c2net, 'C2Net'
  end

  # --- Account, orders and products -------------------------------------------

  # Kind of a balance transaction.
  class TransactionType < Enum
    member :register, 1
    member :renew, 2
    member :transfer, 3
    member :restore, 4
    member :deposit, 5
    member :backorder, 6
    member :refund, 7
    member :deduction, 8
    member :pre_register, 9
    member :shopping, 10
    member :reseller_payment, 11
    member :internal_transfer, 12
  end

  # Outcome of a balance transaction.
  class TransactionStatus < Enum
    member :failed, 0
    member :success, 1
    member :canceled, 2
    member :processing, 3
    member :refunded, 4
  end

  # Direction of a balance transaction.
  class ChargeType < Enum
    member :add, 0, aliases: %w[credit], description: 'credit'
    member :subtract, 1, aliases: %w[debit], description: 'debit'
  end

  # Kind of a product.
  class ProductType < Enum
    member :domain, 1
    member :ssl, 2, name: 'SSL'
    member :deposit, 3
    member :domain_trustee, 4
    member :hosting, 5
    member :owner_change, 6
  end

  # Kind of an order.
  class OrderType < Enum
    member :register, 1
    member :renew, 2
    member :transfer, 3
    member :restore, 4
    member :subreseller_transfer, 5
    member :backorder, 6
    member :internal_transfer, 7
    member :charge, 8
    member :trustee, 9
    member :leasing, 10
    member :create, 11
    member :owner_change, 12
  end

  # State of an order.
  class OrderStatus < Enum
    member :active, 1
    member :pending, 2
    member :canceled, 3
    member :in_progress, 4
  end

  # State of an order line.
  class OrderProductStatus < Enum
    member :ordered, 1
    member :canceled, 2
    member :in_progress, 3
  end
end
