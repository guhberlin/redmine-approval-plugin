



module SubversionPatch

  def self.included(base) # :nodoc:
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :fetch_changesets, :approvals
    end
  end

  module ClassMethods
  end

  module InstanceMethods

    def fetch_changesets_with_approvals
      logger.info("--------------------------------------------------------------------------")
      logger.info("alias method chain im subversion model patch (fetch_changesets_with_approvals)")
      logger.info("--------------------------------------------------------------------------")
      scm_info = scm.info
      if scm_info
        # latest revision found in database
        db_revision = latest_changeset ? latest_changeset.revision.to_i : 0
        # latest revision in the repository
        scm_revision = scm_info.lastrev.identifier.to_i
        if db_revision < scm_revision
          logger.debug "Fetching changesets for repository #{url}" if logger && logger.debug?
          identifier_from = db_revision + 1
          while (identifier_from <= scm_revision)
            # loads changesets by batches of 200
            identifier_to = [identifier_from + 199, scm_revision].min
            revisions = scm.revisions('', identifier_to, identifier_from, :with_paths => true)
            revisions.reverse_each do |revision|
              transaction do
                changeset = Changeset.create(:repository   => self,
                                             :revision     => revision.identifier,
                                             :committer    => revision.author,
                                             :committed_on => revision.time,
                                             :comments     => revision.message)

                revision.paths.each do |change|
                  changeset.create_change(change)
                end unless changeset.new_record?
              end
            end unless revisions.nil?
            identifier_from = identifier_to + 1
          end
        end
      end
    end

  end
end

# Repository::Subversion.send(:include, SubversionPatch)