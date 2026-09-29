package httpx

import "core:testing"

@(test)
test_if_none_match_uses_weak_comparison_over_a_list :: proc(t: ^testing.T) {
	etag := `"a25d30add5a661bc"`
	testing.expect(t, if_none_match_covers(`"a25d30add5a661bc"`, etag))
	testing.expect(t, if_none_match_covers(`W/"a25d30add5a661bc"`, etag))
	testing.expect(t, if_none_match_covers(`"other", W/"a25d30add5a661bc"`, etag))
	testing.expect(t, if_none_match_covers("*", etag))
	testing.expect(t, !if_none_match_covers("", etag))
	testing.expect(t, !if_none_match_covers(`"other"`, etag))
	testing.expect(t, !if_none_match_covers(`a25d30add5a661bc`, etag))
}
