#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

#include "syscore.h"
#include "builtins.h"

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
    start->edges[k]->parent = start;
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

void word_trie_print_words(struct word_trie_node_t* start, char prefix[MAX_WORD_LEN])
{
  int prefix_len = strlen(prefix); 
  if (start->words) {
    fprintf(stderr, " "); 
    fprintf(stderr, "%s", prefix);
  }

  for (int i = 0; i < 128; i++)
  {
    if (!start->edges[i]) continue;

    prefix[prefix_len] = i;
    prefix[prefix_len+1] = '\0';

    word_trie_print_words(start->edges[i], prefix);
  }
}

void stack_push(struct word_trie_node_t** stack, int* stack_idx, struct word_trie_node_t* item)
{
  if (*stack_idx == 0) DIE("stack overflow");
  stack[--(*stack_idx)] = item;
}

struct word_trie_node_t* stack_pop(struct word_trie_node_t** stack, int* stack_idx)
{
  if (*stack_idx >= STACK_SIZE) DIE("stack underflow");
  return stack[(*stack_idx)++];
}

struct env_t* env_new(struct env_t* parent)
{
  struct env_t* env = calloc(1, sizeof(struct env_t));
  env->parent = parent;
  env->stack_idx = STACK_SIZE;
  env->rstack_idx = STACK_SIZE;
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

void EXEC(struct env_t* env, char *word)
{
  struct word_trie_node_t* node = env_lookup(env, word);
  if (!node) DIE("internal compiler error - EXEC non-word"); /* sanity check */

  env->ip = node;
  builtin_execute(env); 
}

#define BUILTIN(vector, wrd, type, immediate, fn)                 \
void builtin_##vector(struct env_t* env)                          \
{                                                                 \
  const char* word = wrd;                                         \
fn                                                                \
}

#include "builtins.h"

#undef BUILTIN

void root_env_init(struct env_t* env)
{
  struct word_trie_node_t* node = 0;
  
#define BUILTIN(vector, word, t, imm, fn)                 \
  node = env_add(env, word);                              \
  node->type = node_##t;                                  \
  node->immediate = imm;                                  \
  node->code = builtin_##vector;                          \

#include "builtins.h"
#undef BUILTIN
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

    if (!trie_node) {
      /* try to parse as a number */
      char* parse_end = 0;
      long number_val = strtol(cur_env->cur_word, &parse_end, 10);

      if (*cur_env->cur_word != '\0' && *parse_end=='\0') {
        trie_node = env_add(cur_env, cur_env->cur_word);
        trie_node->type = node_number;
        trie_node->code = builtin_number;
        trie_node->param = calloc(1, sizeof(struct word_ptr_node_t));
        trie_node->param->word = (struct word_trie_node_t*)number_val;
      } 
    }

    if (trie_node)  {
      cur_env->ip = trie_node;
      builtin_0(cur_env); /* HACK: We know builtin_0 is execute */
    } else {
      fprintf(stderr, "Error: %s is undefined\n", cur_env->cur_word);
      fpurge(stdin);
    }
  }
  return 0;

}
