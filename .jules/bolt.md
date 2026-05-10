Learned that chained list.where().toList() creates multiple intermediate lists and iterating the list multiple times which reduces performance. Can be fixed by looping with a single where() call
