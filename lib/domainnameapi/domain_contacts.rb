# frozen_string_literal: true

module DomainNameApi
  # Replaces contacts of a domain with inline contact details. Roles left out
  # stay as they are. CLI: dna domain contacts update
  class DomainContactsUpdateRequest < BaseRequest
    endpoint :put, '/api/v1/domains/contacts/update', safety: :write
    attribute :domain_name
    # The new contacts: DomainContacts, a Hash of roles, or one Contact for all
    # four. Changing the registrant may start an owner-change process, with
    # documents on some TLDs.
    attribute :contacts

    def body
      { 'domainName' => clean(domain_name), 'contacts' => contacts.nil? ? [] : DomainContacts.coerce(contacts).items }
    end

    def validate
      required :domain_name
      return invalid(:contacts, 'needs at least one contact') if contacts.nil?

      DomainContacts.coerce(contacts).validate_into(validator, :contacts, all: false)
    end
  end

  # Points contact roles of a domain at existing contact handles. Roles left
  # out stay as they are. CLI: dna domain contacts set-handles
  class DomainContactsSetHandlesRequest < BaseRequest
    endpoint :put, '/api/v1/domains/contacts/update-with-handle', safety: :write
    attribute :domain_name
    # ContactHandles, a Hash of roles, or one handle for all four.
    attribute :handles

    def body
      { 'domainName' => clean(domain_name),
        'handleItems' => handles.nil? ? [] : ContactHandles.coerce(handles).items }
    end

    def validate
      required :domain_name
      return invalid(:handles, 'needs at least one handle') if handles.nil?

      ContactHandles.coerce(handles).validate_into(validator, :handles, all: false)
    end
  end

  class DomainService < Service
    # Replaces contacts of a domain with inline details; roles left out stay.
    #
    #   client.domains.update_contacts('example.com', billing: billing_contact)
    def update_contacts(domain_name, contacts = nil, **roles)
      call(DomainContactsUpdateRequest.new(domain_name: domain_name, contacts: contacts || roles))
      nil
    end

    # Points contact roles of a domain at existing handles; roles left out stay.
    #
    #   client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2')
    def set_contact_handles(domain_name, handles = nil, **roles)
      call(DomainContactsSetHandlesRequest.new(domain_name: domain_name, handles: handles || roles))
      nil
    end
  end
end
