#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

#define DIE(s) fprintf(stderr, "ERROR: %s\n", s), exit(1);

#define MAX_WORD_LEN  32
#define STACK_SIZE    1024

struct list_node_t {
  struct list_node_t* next;
} list_node;

size_t list_count(struct list_node_t* list)
{
  size_t count = 0;
  while (++count && (list = list->next)) ;

  return count;
}

struct word_trie_node_t;
struct word_ptr_node_t {
  struct list_node_t list_node;

  struct word_trie_node_t* word;
} word_ptr_node;

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

  /* TODO: Should actually be a list so FORGET will work (or will envs handle
   * it?)
   */
  enum node_type_t type;
  int immediate;      /* If a non-fragment node, whether this node executes 
                         immediately regardless of interpreter mode
                      */

  void (*code)(struct env_t* env);
  struct word_ptr_node_t* param;

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
  int words = start->words > 0 ? 1 : 0; /* Don't count redefines */

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

  return word_node;
}

enum interpreter_mode_t {
  imode_interpret,
  imode_compile
} interpreter_mode;

struct env_t {
  struct env_t* parent;
  enum interpreter_mode_t mode;
  
  struct word_trie_node_t* ip;  /* instruction pointer */
  char cur_word[MAX_WORD_LEN + 1];
  int cur_word_idx;

  struct word_trie_node_t* dictionary;
  
  struct word_trie_node_t* stack[STACK_SIZE];
  int stack_idx;

  struct word_trie_node_t* rstack[STACK_SIZE];
  int rstack_idx;
};

struct env_t* env_new(struct env_t* parent)
{
  struct env_t* env = calloc(1, sizeof(struct env_t));
  env->parent = parent;
  env->stack_idx = STACK_SIZE - 1;
  env->rstack_idx = STACK_SIZE - 1;
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

void builtin_words(struct env_t* env)
{
  /* TODO: implement when we have iterator and args */
}

void builtin_read_word(struct env_t* env)
{
  int ch = 0;

  bzero(env->cur_word, MAX_WORD_LEN + 1);
  env->cur_word_idx = 0;
  while ((ch = getchar()) != EOF)  {
    if (isspace(ch))  {
      if (!env->cur_word_idx)  continue;
      return; 
    }

    if (env->cur_word_idx >= MAX_WORD_LEN) DIE("Word is too long");

    env->cur_word[env->cur_word_idx++] = ch;
  }

  if (ch == EOF) builtin_bye(env);
}

void builtin_execute(struct env_t* env)
{
  if (!env->ip) DIE("internal compiler error - no instruction pointer");

  if (env->mode == imode_interpret || env->ip->immediate) {
    env->ip->code(env);
  } else if (env->mode == imode_compile) {
    struct word_ptr_node_t* last = env->ip->param;
    while (last && last->list_node.next) last = (struct word_ptr_node_t*)last->list_node.next;

    last = calloc(1, sizeof(struct word_ptr_node_t));
    if (!env->ip->param) env->ip->param = last;

    last->word = env->ip;
  } else {
    DIE("internal compiler error - unimplemented compiler mode");
  }
}

void builtin_call(struct env_t* env)
{
  /* like execute but saves the call stack */
  if (env->rstack_idx == 0) DIE("stack overflow");
  if (env->rstack_idx >= STACK_SIZE) DIE("stack underflow");

  env->rstack[--env->rstack_idx] = env->ip;
  struct word_ptr_node_t* p = env->ip->param;
  while (p) {
    fprintf(stderr, "HUH?\n");
    env->ip = p->word;
    builtin_execute(env);
    p = (struct word_ptr_node_t*)p->list_node.next;
  }
  
  if (env->rstack_idx >= STACK_SIZE) DIE("stack underflow");
  env->ip = env->rstack[env->rstack_idx++];
}

void builtin__colon_(struct env_t* env)
{
  builtin_read_word(env);
  env->ip = env_add(env, env->cur_word);
  env->ip->type = node_normal;
  env->ip->code = builtin_call;
  env->mode = imode_compile;
}

void builtin__semicolon_(struct env_t* env)
{
  env->ip = 0; /* TODO: Restore rstack */
  env->mode = imode_interpret;
}

void builtin__dbg(struct env_t* env)
{
  word_trie_print(env->dictionary, 0, stderr);
}

void root_env_init(struct env_t* env)
{
  struct word_trie_node_t* node = 0;
  
  node = env_add(env, ":");
  node->type = node_code;
  node->code = builtin__colon_;

  node = env_add(env, ";");
  node->type = node_code;
  node->immediate = 1;
  node->code = builtin__semicolon_;

  node = env_add(env, "execute");
  node->type = node_code;
  node->code = builtin_execute;

  node = env_add(env, "call");
  node->type = node_code;
  node->code = builtin_call;
  
  node = env_add(env, "_dbg");
  node->type = node_code;
  node->code = builtin__dbg;

  node = env_add(env, "words");
  node->type = node_code;
  node->code = builtin_words;

  node = env_add(env, "read_word");
  node->type = node_code;
  node->code = builtin_read_word;

  node = env_add(env, "bye"); 
  node->type = node_code;
  node->code = builtin_bye; 
}

int main(int argc, char** argv)
{
  struct env_t* root_env = env_new(0);
  root_env->dictionary = word_trie_init(0);
  root_env_init(root_env);

  struct env_t* cur_env = root_env;
    
  fprintf(stderr, "Syslang Forthish Bootstrap v0.1\n%d words in top-level dictionary\n", 
      word_trie_count_all_words(cur_env->dictionary));

  fprintf(stderr, "\n");
  while (1) {
    builtin_read_word(cur_env);
    struct word_trie_node_t* trie_node = env_lookup(cur_env, cur_env->cur_word);
    if (trie_node)  {
      cur_env->ip = trie_node;
      builtin_execute(cur_env);
    } else {
      fprintf(stderr, "Error: %s is undefined\n", cur_env->cur_word);
    }
  }
  return 0;

}
