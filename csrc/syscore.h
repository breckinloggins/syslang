#ifndef SYSCORE_H
#define SYSCORE_H

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
  node_number,                /* A number literal */
  node_pointer,               /* Points to another node in the trie */
  node_code                   /* Contains executable code */
} node_type;

struct env_t;                 /* Forward decl */
struct word_trie_node_t {
  struct word_trie_node_t* parent; /* Parent node in trie, not parent word */

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

enum interpreter_mode_t {
  imode_interpret,
  imode_compile
} interpreter_mode;

struct env_t {
  struct env_t* parent;
  enum interpreter_mode_t mode;
  
  struct word_trie_node_t* compiling_word;
  struct word_trie_node_t* ip;  /* instruction pointer */
  char cur_word[MAX_WORD_LEN + 1];
  int cur_word_idx;

  struct word_trie_node_t* dictionary;
  
  struct word_trie_node_t* stack[STACK_SIZE];
  int stack_idx;

  struct word_trie_node_t* rstack[STACK_SIZE];
  int rstack_idx;
};

struct word_trie_node_t* word_trie_init(struct word_trie_node_t* node);
struct word_trie_node_t* word_trie_insert(struct word_trie_node_t* start, char* str, struct word_trie_node_t** leaf);
struct word_trie_node_t* word_trie_lookup(struct word_trie_node_t* start, char *word);
struct word_trie_node_t* stack_pop(struct word_trie_node_t** stack, int* stack_idx);
struct env_t* env_new(struct env_t* parent);
struct word_trie_node_t* env_add(struct env_t* env, char* word);
struct word_trie_node_t* env_lookup(struct env_t* env, char* word);
int word_trie_count_words(struct word_trie_node_t* start, char* str, struct word_trie_node_t** leaf);
void word_trie_print(struct word_trie_node_t* start, int level, FILE* fp);
int word_trie_count_all_words(struct word_trie_node_t* start);
void word_trie_print_words(struct word_trie_node_t* start, char prefix[MAX_WORD_LEN]);
void stack_push(struct word_trie_node_t** stack, int* stack_idx, struct word_trie_node_t* item);
void EXEC(struct env_t* env, char *word);

#endif // SYSCORE_H
