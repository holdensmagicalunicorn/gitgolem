require 'helper'

class TestAccess < WithTestDb
    def test_access
	repos.each do |user, repos|
	    (repos.is_a?(Array) ? repos : [repos]).each do |repo|
		assert Golem::Access.check(user, repo, 'unused'), "access check failed for #{user.to_s}, #{repo.to_s}"
	    end
	end
    end

    def test_return_values
	assert_kind_of Array, Golem::Access.users
	assert_equal users, Golem::Access.users
	assert_kind_of Array, Golem::Access.repositories
	assert_equal repos.values.flatten, Golem::Access.repositories
	assert_kind_of Hash, Golem::Access.ssh_keys
	assert_equal keys.inject({}) {|m, (u, k)| m[u] = k.is_a?(Array) ? k : [k]; m}, Golem::Access.ssh_keys
    end
end
