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

enum node_type_t {
  node_fragment = 0,          /* Part of a word only */
  node_normal,                /* A normal word (TODO: What does this mean?) */
  node_pointer,               /* Points to another node in the trie */
  node_code                   /* Contains executable code */
} node_type;

struct env_t;                 /* Forward decl */
struct word_trie_node_t {
  int words;          /* Number of words terminating here */
  int prefixes;       /* Number of words for which this is a prefix */

  enum node_type_t type;
  int immediate;      /* If a non-fragment node, whether this node executes 
                         immediately regardless of interpreter mode
                      */

  union {
    void (*code)(struct env_t* env);
  } content;

  struct word_trie_node_t* edges[128]; /* This is obviously inefficient and won't work for unicode */
} word_trie_node;

struct word_trie_node_t* word_trie_init(struct word_trie_node_t* node)
{
  int i;
  if (!node)  {
    node = (struct word_trie_node_t*)calloc(1, sizeof(struct word_trie_node_t));
  }

  return node;
}

struct word_trie_node_t* word_trie_insert(struct word_trie_node_t* start, char* str, struct word_trie_node_t** leaf)
{
  if (str[0] == '\0') {
    if (leaf) *leaf = start;
    start->words = start->words + 1;
    return start;
  }

  start->prefixes = start->prefixes + 1;
  char k = str[0];
  ++str;
  if (!start->edges[k]) {
    start->edges[k] = word_trie_init(0);
  }
  start->edges[k] = word_trie_insert(start->edges[k], str, leaf);

  return start;
}

int word_trie_count_words(struct word_trie_node_t* start, char* str, struct word_trie_node_t** leaf)
{
  if (str[0] == '\0') {
    if (leaf) *leaf = start;
    return start->words;
  }

  char k = str[0];
  ++str;

  if (!start->edges[k]) {
    if (leaf) *leaf = 0;
    return 0;
  }

  return word_trie_count_words(start->edges[k], str, leaf);
}

int word_trie_count_prefixes(struct word_trie_node_t* start, char* str)
{
  if (str[0] == '\0') {
    return start->prefixes;
  }

  char k = str[0];
  ++str;

  if (!start->edges[k]) {
    return 0;
  }

  return word_trie_count_prefixes(start->edges[k], str);
}

void word_trie_print(struct word_trie_node_t* start, int level, FILE* fp)
{
  for (int i = 0; i < level; i++) fprintf(fp, "  ");
  fprintf(fp, "W: %d, P:%d, T: %d, I: %d\n", 
      start->words, start->prefixes, start->type, start->immediate);
  for (int i = 0; i < 128; i++) {
    if (!start->edges[i]) continue;
    for (int k = 0; k < level; k++) fprintf(fp, "   ");
    fprintf(fp, "'%c':\n", i);
    word_trie_print(start->edges[i], level+1, fp); 
  }
}

int word_trie_count_all_words(struct word_trie_node_t* start)
{
  int words = start->words;

  for (int i = 0; i < 128; i++) {
    if (!start->edges[i]) continue;
    words += word_trie_count_all_words(start->edges[i]);
  }

  return words;
}

struct word_trie_node_t* word_trie_lookup(struct word_trie_node_t* start, char *word)
{
  struct word_trie_node_t* word_node = 0;
  int word_count = 0;
  if (!(word_count = word_trie_count_words(start, word, &word_node)) 
      || !word_node
      || !word_node->type)  {
     return 0; 
  }

  if (word_count > 1) DIE("internal compiler error - invalid word count"); /* Sanity check */

  return word_node;
}

enum interpreter_mode_t {
  imode_interpret,
  imode_compile
} interpreter_mode;

struct env_t {
  struct env_t* parent;
  enum interpreter_mode_t mode;
  struct word_trie_node_t* dictionary;
};

struct env_t* env_new(struct env_t* parent)
{
  struct env_t* env = calloc(1, sizeof(struct env_t));
  env->parent = parent;

  return env;
}

struct word_trie_node_t* env_add(struct env_t* env, char* word)
{
  if (!env) DIE("internal compiler error - orphaned environment"); /* Sanity check */
  if (!env->dictionary) return env_add(env->parent, word);
  
  struct word_trie_node_t* node = 0;
  word_trie_insert(env->dictionary, word, &node);
  return node;
}

struct word_trie_node_t* env_lookup(struct env_t* env, char* word)
{
  if (!env) DIE("internal compiler error - orphaned environment"); /* Sanity check */
  
  struct word_trie_node_t* node = word_trie_lookup(env->dictionary, word);
  if (node) {
    return node;
  } else if (env->parent) {
    return env_lookup(env->parent, word); 
  } else {
    return 0;
  }
}

void builtin_bye(struct env_t* env)
{
  exit(0);
}

void builtin__dbg(struct env_t* env)
{
  word_trie_print(env->dictionary, 0, stderr);
}

void root_env_init(struct env_t* env)
{
  struct word_trie_node_t* node = 0;
  
  node = env_add(env, ":");
  node->type = node_normal;
  
  node = env_add(env, "_dbg");
  node->type = node_code;
  node->content.code = builtin__dbg;

  node = env_add(env, "bye"); 
  node->type = node_code;
  node->content.code = builtin_bye; 
}

int main(int argc, char** argv)
{
  int ch = 0;

  char cur_word[MAX_WORD_LEN + 1];
  int cur_word_idx = 0;

  struct env_t* root_env = env_new(0);
  root_env->dictionary = word_trie_init(0);
  root_env_init(root_env);

  struct env_t* cur_env = root_env;

  bzero(cur_word, MAX_WORD_LEN + 1);
    
  fprintf(stderr, "Syslang Forthish Bootstrap v0.1\n%d words in top-level dictionary\n", 
      word_trie_count_all_words(cur_env->dictionary));

  fprintf(stderr, "\n");
  while ((ch = getchar()) != EOF)  {
    if (isspace(ch))  {
      if (!cur_word_idx)  continue;

      struct word_trie_node_t* trie_node = env_lookup(cur_env, cur_word);
      if (trie_node)  {
        if (trie_node->type == node_code) {
          trie_node->content.code(cur_env);
        }
      } else {
        fprintf(stderr, "Error: %s is undefined\n", cur_word);
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
