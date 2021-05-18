package roxci

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestFailsToLoad(t *testing.T) {
	_, err := LoadRecipes("no-existo")
	assert.NotNil(t, err)
	assert.Regexp(t, ".*no such file.*", err)
}

func TestBadlyFormedYaml(t *testing.T) {
	_, err := LoadRecipes("testfiles/badyaml.yml")
	assert.NotNil(t, err)
	assert.Regexp(t, "cannot parse recipes: .*", err)
}

func TestMissingRequiredFieldDescription(t *testing.T) {
	_, err := LoadRecipes("testfiles/missing.yml")
	assert.NotNil(t, err)
	assert.EqualError(t, err, "recipe two is missing a description")
}

func TestMissingRequiredFieldJobs(t *testing.T) {
	_, err := LoadRecipes("testfiles/missing2.yml")
	assert.NotNil(t, err)
	assert.EqualError(t, err, "recipe two is missing jobs")
}

func TestValid(t *testing.T) {
	recipes, err := LoadRecipes("testfiles/valid.yml")
	assert.Nil(t, err)
	assert.Equal(t, len(*recipes), 3)
	assert.EqualValues(t, map[string]string{"a": "", "b": "", "d": ""}, (*recipes)[2].Jobs)
}
