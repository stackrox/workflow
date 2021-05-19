package roxci

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

var (
	validRecipes, _ = LoadRecipes("testfiles/valid.yml")
)

func TestNoCommits(t *testing.T) {
	run, err := Check("a", []string{}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestJobInSimpleRecipeCommand(t *testing.T) {
	run, err := Check("a", []string{"/roxci one"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestJobInVerboseRecipeCommand(t *testing.T) {
	run, err := Check("a", []string{"/roxci recipe=two"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestJobNotInSimpleRecipeCommand(t *testing.T) {
	run, err := Check("d", []string{"/roxci one"}, validRecipes)
	assert.Nil(t, err)
	assert.False(t, run)
}

func TestJobNotInVerboseRecipeCommand(t *testing.T) {
	run, err := Check("d", []string{"/roxci recipe=two"}, validRecipes)
	assert.Nil(t, err)
	assert.False(t, run)
}

func TestMissingRecipe(t *testing.T) {
	run, err := Check("a", []string{"/roxci four"}, validRecipes)
	assert.EqualError(t, err, "there is no such recipe: four")
	assert.True(t, run)
}

func TestMissingVerboseRecipe(t *testing.T) {
	run, err := Check("a", []string{"/roxci recipe=four"}, validRecipes)
	assert.EqualError(t, err, "there is no such recipe: four")
	assert.True(t, run)
}

func TestJobExcluded(t *testing.T) {
	run, err := Check("a", []string{"/roxci recipe=one exclude=a"}, validRecipes)
	assert.Nil(t, err)
	assert.False(t, run)
}

func TestJobExcludedWhenMany(t *testing.T) {
	run, err := Check("a", []string{"/roxci recipe=one exclude=b,a"}, validRecipes)
	assert.Nil(t, err)
	assert.False(t, run)
}

func TestJobInComposedRecipes(t *testing.T) {
	run, err := Check("c", []string{"/roxci one,two"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
	run, err = Check("a", []string{"/roxci one,two"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestJobNotInComposedRecipes(t *testing.T) {
	run, err := Check("d", []string{"/roxci one,two"}, validRecipes)
	assert.Nil(t, err)
	assert.False(t, run)
}

func TestJobInComposedRecipesII(t *testing.T) {
	run, err := Check("c", []string{"/roxci recipe=one,two"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
	run, err = Check("a", []string{"/roxci recipe=two recipe=one"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestJobExcludedWhenManyMore(t *testing.T) {
	run, err := Check("a", []string{"/roxci recipe=one exclude=b exclude=a"}, validRecipes)
	assert.Nil(t, err)
	assert.False(t, run)
}

func TestCaseAmbivalence(t *testing.T) {
	run, err := Check("a", []string{"/roXci recIpe=oNe eXclude=b eXclude=a"}, validRecipes)
	assert.Nil(t, err)
	assert.False(t, run)
}

func TestCaseAmbivalenceII(t *testing.T) {
	run, err := Check("a", []string{"/roXci recIpe=oNe eXclude=b eXclude=A"}, validRecipes)
	assert.Nil(t, err)
	assert.False(t, run)
}

func TestCaseAmbivalenceIII(t *testing.T) {
	run, err := Check("a", []string{"/roXci recIpe=oNe"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestJobIncluded(t *testing.T) {
	run, err := Check("d", []string{"/roxci recipe=one include=d"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestJobIncludedMany(t *testing.T) {
	run, err := Check("e", []string{"/roxci recipe=one include=e,d"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestJobIncludedManyMore(t *testing.T) {
	run, err := Check("e", []string{"/roxci recipe=one include=e include=d"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestManyCommits(t *testing.T) {
	run, err := Check("e", []string{"testing", "/roxci recipe=one include=e,d", "123"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestManyCommitsMostRecentWins(t *testing.T) {
	run, err := Check("e",
		[]string{"testing", "/roxci recipe=one", "/roxci recipe=one include=e,d", "123"}, validRecipes)
	assert.Nil(t, err)
	assert.False(t, run)
}

func TestExplicitDefault(t *testing.T) {
	run, err := Check("e",
		[]string{"testing", "/roxci default", "/roxci recipe=one include=e,d", "123"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}

func TestMoreExplicitDefault(t *testing.T) {
	run, err := Check("e",
		[]string{"testing", "/roxci recipe=default", "/roxci recipe=one include=e,d", "123"}, validRecipes)
	assert.Nil(t, err)
	assert.True(t, run)
}
