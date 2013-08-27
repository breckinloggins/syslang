#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

#define DIE(s) fprintf(stderr, "ERROR: %s\n", s), exit(1);

#define MAX_WORD_LEN  32

struct list_node_t {
  struct list_node_t* next;
} list_node;

size_t list_count(struct list_node_t* list)
{
  size_t count = 0;
  while (++count && (list = list->next)) ;

  return count;
}

enum interpreter_mode_t {
  imode_interpret,
  imode_compile
} interpreter_mode;
    
struct word_list_node_t {
  struct list_node_t node;

  char word[MAX_WORD_LEN + 1];
  struct word_list_node_t* definition;
  void (*builtin_fn)(struct word_list_node_t* words_context);
} word_list_node;

struct word_tree_node_t {

  int ch;
  
  int edges[128]; /* This is obviously inefficient and won't work for unicode */

} word_tree_node;

struct word_list_node_t* word_lookup(struct word_list_node_t* word_list, const char* word)
{
  /* Yes, I know a hashtable would be faster */
  if (!word_list) return 0;

  if (!(strncmp(word, word_list->word, strlen(word)))) {
    return word_list;
  }

  return word_lookup((struct word_list_node_t*)word_list->node.next, word);
}

struct word_list_node_t* word_prepend(struct word_list_node_t* word_list, const char* word)
{
  struct word_list_node_t* word_node = calloc(1, sizeof(struct word_list_node_t));
  strncpy(word_node->word, word, MAX_WORD_LEN);

  word_node->node.next = (struct list_node_t*)word_list;
  return word_node;
}

void builtin_bye(struct word_list_node_t* word_context)
{
  exit(0);
}

struct word_list_node_t* word_bootstrap_words()
{
  struct word_list_node_t* builtins = word_prepend(0, ":");

  builtins = word_prepend(builtins, "bye");
  builtins->builtin_fn = builtin_bye;

  return builtins;
}

int main(int argc, char** argv)
{
  int ch = 0;

  char cur_word[MAX_WORD_LEN + 1];
  int cur_word_idx = 0;

  enum interpreter_mode_t imode = imode_interpret;
  struct word_list_node_t* words = word_bootstrap_words();

  bzero(cur_word, MAX_WORD_LEN + 1);
    
  fprintf(stderr, "Syslang Forthish Bootstrap v0.1\n%ld words in top-level dictionary\n", 
      list_count((struct list_node_t*)words));

  while ((ch = getchar()) != EOF)  {
    if (isspace(ch))  {
      if (!cur_word_idx)  continue;

      //fprintf(stderr, "Debug: cur_word is %s\n", cur_word);

      struct word_list_node_t* word_node = word_lookup(words, (const char*)cur_word);
      if (!word_node) {
        fprintf(stderr, "Error: %s is undefined\n", cur_word);
      } else {
        if (word_node->builtin_fn)  {
          word_node->builtin_fn(words);
        } else {
          // Recursive!
        }
      }

      bzero(cur_word, MAX_WORD_LEN + 1);
      cur_word_idx = 0;
      continue;
    }

    if (cur_word_idx >= MAX_WORD_LEN) DIE("Word is too long");

    cur_word[cur_word_idx++] = ch;
    
  }
  return 0;
}
