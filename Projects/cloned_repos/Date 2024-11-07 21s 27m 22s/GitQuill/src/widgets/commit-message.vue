
<template>
    <span v-for="part in parts">
        <a
            v-if="part.href"
            class="border-b border-dashed"
            :href="part.href"
            target="_blank"
        >
            {{ part.text }}
        </a>
        <span v-else>
            {{ part.text }}
        </span>
    </span>
</template>

<script>
    export default {
        inject: ['config'],
        props: {
            content: { type: String, required: true },
        },
        computed: {
            parts() {
                const parts = [{ text: this.content }];

                for (let [regex, replacer] of this.config?.autolinks ?? []) {
                    regex = new RegExp(regex, 'g');
                    for (let i = 0; i < parts.length; ++i) {
                        if (parts[i].href === undefined) {
                            const text = parts[i].text;
                            let last_index = 0;
                            const new_parts = [];
                            for (const match of text.matchAll(regex)) {
                                new_parts.push({
                                    text: text.slice(last_index, match.index),
                                });
                                last_index = match.index + match[0].length;
                                new_parts.push({
                                    text: text.slice(match.index, last_index),
                                    href: match[0].replace(regex, replacer),
                                });
                            }
                            new_parts.push({
                                text: text.slice(last_index),
                            });
                            parts.splice(i, 1, ...new_parts);
                            i += new_parts.length - 1;
                        }
                    }
                }
                return parts;
            }
        },
    };
</script>
