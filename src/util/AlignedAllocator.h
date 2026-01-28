#ifndef HEMELB_UTIL_ALIGNEDALLOCATOR_H
#define HEMELB_UTIL_ALIGNEDALLOCATOR_H

#include <cstdlib>
#include <new>
#include <limits>

namespace hemelb
{
    namespace util 
    {
        template <typename T, std::size_t Alignment>
        class AlignedAllocator
        {
        public:
            using value_type = T;
            using pointer = T*;
            using const_pointer = const T*;
            using reference = T&;
            using const_reference = const T&;
            using size_type = std::size_t;
            using difference_type = std::ptrdiff_t;
            
            template<class U> struct rebind { using other = AlignedAllocator<U, Alignment>; };

            AlignedAllocator() noexcept {}
            template <class U> AlignedAllocator(const AlignedAllocator<U, Alignment>&) noexcept {}

            T* allocate(std::size_t n)
            {
                if (n > std::numeric_limits<std::size_t>::max() / sizeof(T))
                    throw std::bad_alloc();

                void* ptr = nullptr;
                if (posix_memalign(&ptr, Alignment, n * sizeof(T)) != 0)
                    throw std::bad_alloc();

                return static_cast<T*>(ptr);
            }

            void deallocate(T* p, std::size_t) noexcept
            {
                free(p);
            }
            
            bool operator==(const AlignedAllocator&) const noexcept { return true; }
            bool operator!=(const AlignedAllocator&) const noexcept { return false; }
        };

        // Helper functions for manual allocation
        template <typename T, std::size_t Alignment = 64>
        T* allocate_aligned(std::size_t n) {
            if (n > std::numeric_limits<std::size_t>::max() / sizeof(T))
                throw std::bad_alloc();
            void* ptr = nullptr;
            if (posix_memalign(&ptr, Alignment, n * sizeof(T)) != 0) {
                 throw std::bad_alloc();
            }
            return static_cast<T*>(ptr);
        }

        template <typename T>
        void free_aligned(T* ptr) {
            free(ptr);
        }
    }
}

#endif // HEMELB_UTIL_ALIGNEDALLOCATOR_H
