# Copyright (c) 2024, Alibaba Group;
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#    http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import csv
import os
import shutil
import tempfile
import unittest

from tzrec.tools.tdm.gen_tree.tree_cluster import TreeCluster
from tzrec.tools.tdm.gen_tree.tree_search_util import TreeSearch


class TreeSearchtest(unittest.TestCase):
    def setUp(self) -> None:
        if not os.path.exists("./tmp"):
            os.makedirs("./tmp")
        self.test_dir = tempfile.mkdtemp(prefix="tzrec_", dir="./tmp")
        self.tmp_file = tempfile.NamedTemporaryFile(
            dir=self.test_dir, mode="w", delete=False, newline="", suffix=".csv"
        )
        writer = csv.writer(self.tmp_file)
        writer.writerow(["item_id", "int_a", "float_b", "str_c", "item_emb"])
        for i in range(6):
            writer.writerow([i, i, 0.1 * i, f"我们{i}", [i] * 4])
        self.tmp_file.close()

    def tearDown(self) -> None:
        shutil.rmtree(self.test_dir)

    def test_cluster(self) -> None:
        cluster = TreeCluster(
            item_input_path=self.tmp_file.name,
            item_id_field="item_id",
            attr_fields="int_a,str_c",
            raw_attr_fields="float_b",
            output_file=None,
            embedding_field="item_emb",
            parallel=1,
            n_cluster=2,
        )

        root = cluster.train(save_tree=False)
        search = TreeSearch(output_file=self.test_dir, root=root, child_num=2)
        search.save()
        search.save_predict_edge(3)

        node_table = []
        edge_table = []
        predict_edge_table = []
        with open(os.path.join(self.test_dir, "node_table.txt")) as f:
            for line in f:
                node_table.append(line)

        with open(os.path.join(self.test_dir, "edge_table.txt")) as f:
            for line in f:
                edge_table.append(line)

        with open(os.path.join(self.test_dir, "predict_edge_table.txt")) as f:
            for line in f:
                predict_edge_table.append(line)

        self.assertEqual(len(node_table), 14)
        self.assertEqual(len(edge_table), 19)
        self.assertEqual(len(predict_edge_table), 7)


if __name__ == "__main__":
    unittest.main()
